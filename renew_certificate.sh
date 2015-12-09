#!/bin/bash

# do nothing if certificate is valid for more than 30 days (30*24*60*60)
openssl x509 -noout -in letsencrypt/signed.crt -checkend 2592000 && exit

/etc/init.d/Qthttpd.sh stop
/etc/init.d/stunnel.sh stop

mkdir -p tmp-webroot/.well-known/acme-challenge
cd tmp-webroot
python -m SimpleHTTPServer 80 &
cd ..
pid=$!
echo "Started with pid $pid"

export SSL_CERT_FILE=/etc/ssl/ca-bundle.crt
python acme-tiny/acme_tiny.py --account-key letsencrypt/account.key --csr letsencrypt/domain.csr --acme-dir tmp-webroot/.well-known/acme-challenge > letsencrypt/signed.crt
wget -O - https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.pem > letsencrypt/intermediate.pem
cat letsencrypt/signed.crt letsencrypt/intermediate.pem > letsencrypt/chained.pem
cat letsencrypt/keys/domain.key letsencrypt/chained.pem > /etc/stunnel/stunnel.pem
cp letsencrypt/intermediate.pem /etc/stunnel/uca.pem

/etc/init.d/stunnel.sh start

kill -9 $pid
rm -rf tmp-webroot

/etc/init.d/Qthttpd.sh start
