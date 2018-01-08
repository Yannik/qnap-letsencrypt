#!/bin/bash
set -e

# do nothing if certificate is valid for more than 30 days (30*24*60*60)
echo "Checking whether to renew certificate on $(date -R)"
[ -s letsencrypt/signed.crt ] && openssl x509 -noout -in letsencrypt/signed.crt -checkend 2592000 && exit

if python -c "import SimpleHTTPServer"; then
    PYTHON=python
elif "$(/sbin/getcfg Python Install_Path -f /etc/config/qpkg.conf)/bin/python2" -c "import SimpleHTTPServer"; then
    PYTHON="$(/sbin/getcfg Python Install_Path -f /etc/config/qpkg.conf)/bin/python2"
elif "$(/sbin/getcfg Python Install_Path -f /etc/config/qpkg.conf)/src/bin/python2" -c "import SimpleHTTPServer"; then
    PYTHON="$(/sbin/getcfg Python Install_Path -f /etc/config/qpkg.conf)/src/bin/python2"
elif /sbin/getcfg Python3 Install_Path -f /etc/config/qpkg.conf; then
    PYTHON="$(/sbin/getcfg Python3 Install_Path -f /etc/config/qpkg.conf)/python3/bin/python3"
else
    echo "Error: You need to install the python 2.7 or 3.5 qpkg!"
    exit 1
fi

echo "Renewing certificate..."
echo "Stopping Qthttpd hogging port 80.."

/etc/init.d/Qthttpd.sh stop

mkdir -p tmp-webroot/.well-known/acme-challenge
cd tmp-webroot
"$PYTHON" ../HTTPServer.py &
pid=$!
cd ..
echo "Started python HTTP server with pid $pid"

domainstr=$(openssl req -in letsencrypt/domain.csr -noout -text| sed -n 's/DNS://gp')
domains=(${domainstr//,/})
for i in "${domains[@]}"; do
    if ! [[ $(wget -q -t 1 --spider --dns-timeout 3 --connect-timeout 5  $i:80; echo $?) -eq 0 ]]; then 
        echo -e  "Error: $i cannot be reached on port 80! check your DNS, port forwarding and firewall!"
        exit 1
    fi
done

export SSL_CERT_FILE=cacert.pem
"$PYTHON" acme-tiny/acme_tiny.py --account-key letsencrypt/account.key --csr letsencrypt/domain.csr --acme-dir tmp-webroot/.well-known/acme-challenge > letsencrypt/signed.crt
echo "Downloading intermediate certificate..."
wget --no-verbose -O - https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem > letsencrypt/intermediate.pem
cat letsencrypt/signed.crt letsencrypt/intermediate.pem > letsencrypt/chained.pem

echo "Stopping stunnel and setting new stunnel certificates..."
/etc/init.d/stunnel.sh stop
cat letsencrypt/keys/domain.key letsencrypt/chained.pem > /etc/stunnel/stunnel.pem
cp letsencrypt/intermediate.pem /etc/stunnel/uca.pem

echo "Done! Service startup and cleanup will follow now..."
/etc/init.d/stunnel.sh start

kill -9 $pid || true
rm -rf tmp-webroot

/etc/init.d/Qthttpd.sh start
