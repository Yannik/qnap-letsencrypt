#!/bin/sh
git clone https://github.com/diafygi/acme-tiny.git
mkdir -p letsencrypt/keys
cd letsencrypt
openssl genrsa 4096 > account.key
openssl genrsa -out keys/domain.key 2048 -sha256

