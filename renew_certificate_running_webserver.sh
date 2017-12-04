#!/bin/bash
set -e

# do nothing if certificate is valid for more than 30 days (30*24*60*60)
echo "Checking whether to renew certificate on $(date -R)"
[ -s letsencrypt/signed.crt ] && openssl x509 -noout -in letsencrypt/signed.crt -checkend 2592000 && exit

echo "Renewing certificate..."

#using running webserver
mkdir -p /share/Web/.well-known/acme-challenge

export SSL_CERT_FILE=cacert.pem
python acme-tiny/acme_tiny.py --account-key letsencrypt/account.key --csr letsencrypt/domain.csr --acme-dir /share/Web/.well-known/acme-challenge > letsencrypt/cert.pem.temp
if [ -f letsencrypt/cert.pem.temp ] && [ -s letsencrypt/cert.pem.temp ] ; then
mv letsencrypt/cert.pem.temp letsencrypt/signed.crt
echo "Downloading intermediate certificate..."
wget --no-verbose -O - https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem > letsencrypt/intermediate.pem
cat letsencrypt/signed.crt letsencrypt/intermediate.pem > letsencrypt/chained.pem

echo "Stopping stunnel and setting new stunnel certificates..."
/etc/init.d/stunnel.sh stop
cat letsencrypt/keys/domain.key letsencrypt/chained.pem > /etc/stunnel/stunnel.pem
cp letsencrypt/intermediate.pem /etc/stunnel/uca.pem

echo "Done! Service startup and cleanup will follow now..."
/etc/init.d/stunnel.sh start

fi

rm -rf /share/Web/.well-known/

/etc/init.d/Qthttpd.sh restart
