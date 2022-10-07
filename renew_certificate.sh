#!/usr/bin/env bash
set -o errexit

trap error_cleanup ERR

error_cleanup() {
  echo "An error occured. Restoring system state."
  cleanup
}

cleanup() {
  [ -n "$pid" ] && kill -9 $pid
  rm -rf tmp-webroot
  /etc/init.d/stunnel.sh start
  /etc/init.d/Qthttpd.sh start
}

# from https://stackoverflow.com/questions/29832037/how-to-get-script-directory-in-posix-sh
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

# do nothing if certificate is valid for more than 30 days (30*24*60*60)
echo "Checking whether to renew certificate on $(date -R)"
[ -s letsencrypt/signed.crt ] && openssl x509 -noout -in letsencrypt/signed.crt -checkend 2592000 && exit

if python3 -c "import http.server" 2> /dev/null; then
    PYTHON=python3
elif "$(/sbin/getcfg QPython3 Install_Path -f /etc/config/qpkg.conf)/bin/python3" -c "import http.server" 2> /dev/null; then
    PYTHON="$(/sbin/getcfg QPython3 Install_Path -f /etc/config/qpkg.conf)/bin/python3"
elif "$(/sbin/getcfg Python3 Install_Path -f /etc/config/qpkg.conf)/python3/bin/python3" -c "import http.server" 2> /dev/null; then
    PYTHON="$(/sbin/getcfg Python3 Install_Path -f /etc/config/qpkg.conf)/python3/bin/python3"
elif "$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf)/bin/python3" -c "import http.server" 2> /dev/null; then
    PYTHON="$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf)/bin/python3"
else
    echo "Error: You need to install the python 3.5 qpkg!"
    exit 1
fi

echo "Renewing certificate..."
[ -e .git ] && echo "qnap-letsencrypt version: $(git rev-parse --short HEAD)"
echo "Using python path: $PYTHON"
echo "Stopping Qthttpd hogging port 80.."

/etc/init.d/Qthttpd.sh stop

for PID in $(lsof -i tcp:80 -a -c python -t)
do
    echo "Killing old python process $PID hogging port 80" && kill $PID && sleep 1
done

mkdir -p tmp-webroot/.well-known/acme-challenge
cd tmp-webroot
"$PYTHON" ../HTTPServer.py &
PID=$!
cd ..
echo "Started python HTTP server with pid $PID"

# Setup up-to-date certificates and bypass system certificate store
export SSL_CERT_FILE=cacert.pem
export SSL_CERT_DIR=/dev/null

"$PYTHON" acme-tiny/acme_tiny.py --account-key letsencrypt/account.key --csr letsencrypt/domain.csr --acme-dir tmp-webroot/.well-known/acme-challenge > letsencrypt/signed.crt.tmp
mv letsencrypt/signed.crt.tmp letsencrypt/signed.crt
echo "Downloading intermediate certificate..."
wget --no-verbose --secure-protocol=TLSv1_2 -O - https://letsencrypt.org/certs/lets-encrypt-r3.pem > letsencrypt/intermediate.pem
cat letsencrypt/signed.crt letsencrypt/intermediate.pem > letsencrypt/chained.pem

echo "Stopping stunnel and setting new stunnel certificates..."
/etc/init.d/stunnel.sh stop
cat letsencrypt/keys/domain.key letsencrypt/chained.pem > /etc/stunnel/stunnel.pem
cp letsencrypt/intermediate.pem /etc/stunnel/uca.pem

# FTP
cp letsencrypt/keys/domain.key /etc/config/stunnel/backup.key
cp letsencrypt/signed.crt /etc/config/stunnel/backup.cert
if pidof proftpd > /dev/null; then
    echo "Restarting FTP"
    /etc/init.d/ftp.sh restart || true
fi

echo "Done! Service startup and cleanup will follow now..."

cleanup
