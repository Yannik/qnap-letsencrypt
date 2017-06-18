#!/bin/bash
set -e

# do nothing if certificate is valid for more than 30 days (30*24*60*60)
echo "Checking whether to renew certificate on $(date -R)"
[ -s letsencrypt/signed.crt ] && openssl x509 -noout -in letsencrypt/signed.crt -checkend 2592000 && exit

echo "Renewing certificate..."
echo "Stopping Qthttpd hogging port 80.."

/etc/init.d/Qthttpd.sh stop

mkdir -p tmp-webroot/.well-known/acme-challenge
cd tmp-webroot
python ../HTTPServer.py &
pid=$!
cd ..
echo "Started python HTTP server with pid $pid"

export SSL_CERT_FILE=cacert.pem
python acme-tiny/acme_tiny.py --account-key letsencrypt/account.key --csr letsencrypt/domain.csr --acme-dir tmp-webroot/.well-known/acme-challenge > letsencrypt/signed.crt
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
