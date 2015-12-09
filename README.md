1. run `init.sh`
2. create a csr:
3. 
**single domain cert:**
```
openssl req -new -sha256 -key keys/domain.key -subj "/CN=nas.xxx.de" > domain.csr
```

**multiple domain cert:**
```
cp /etc/ssl/openssl.cnf openssl-csr-config.cnf
printf "[SAN]\nsubjectAltName=DNS:nas.xxx.de,DNS:xxx.myqnapcloud.com" >> openssl-csr-config.cnf
openssl req -new -sha256 -key keys/domain.key -subj "/" -reqexts SAN -config openssl-csr-config.cnf > domain.csr
``` 
4. `mv /etc/stunnel/stunnel.pem /etc/stunnel/stunnel.pem.orig`
5. run `renew_certificate.sh`
6. account.key, domain.key and even the csr (according to acme-tiny readme) can be reused, so just create a cronjob to run `renew_certificate.sh` every week (preferrably in the night)
