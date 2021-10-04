# Let's Encrypt on QNAP
## Install Instructions
### NAS Setup
1. Login to your NAS and make sure that the `Python 3.5` app is installed.
2. Make sure your NAS is reachable from the public internet under the domain you want to get a certificate for on port 80.
3. Create a folder to store qnap-letsencrypt in under `/share/YOUR_DRIVE/`. Do not create it directly in `/share/`, as it will be lost after a reboot!

### Installing git
If there is a git package available for your NAS model in the QNAP App-Center, use that. 
Otherwise, [install entware](https://github.com/Entware/Entware/wiki/Install-on-QNAP-NAS). Apart from git, it provides many more useful packages. You may need to install `git-http` in addition to `git`.

After logging out and in again, you can use `opkg install git` to install git.

### Setting up a valid ca-bundle and cloning this repo

By default, there is no ca-bundle (bundle of root certificates which we should trust)
installed. Therefore we will have to download one manually.

1. On your local pc with an intact certificate store, run
    ```
    curl --silent https://curl.se/ca/cacert.pem | sha1sum
    ```

2. On your nas, in the directory you want to install qnap-letsencrypt in, run
    ```
    curl --silent --location --remote-name --insecure https://curl.haxx.se/ca/cacert.pem
    sha1sum cacert.pem
    ```

3. Compare the hashes obtained in step 1 and 2, they must match.

4. On your nas, in the directory you were in before
    ```
    git config --system http.sslVerify true
    git config --system http.sslCAinfo `pwd`/cacert.pem
    git clone https://github.com/Yannik/qnap-letsencrypt.git
    mv cacert.pem qnap-letsencrypt
    cd qnap-letsencrypt
    git config --system http.sslCAinfo `pwd`/cacert.pem
    ```

### Setting up qnap-letsencrypt
1. Run `init.sh`

2. Create a Certificate Signing Request(csr):

    **single domain cert:** (replace nas.xxx.de with your domain name)
    ```
    openssl req -new -sha256 -key letsencrypt/keys/domain.key -subj "/CN=nas.xxx.de" > letsencrypt/domain.csr
    ```

    **multiple domain cert:** (replace nas.xxx.de and nas.xxx.com with your domain names)
    ```
    cp openssl.cnf letsencrypt/openssl-csr-config.cnf
    printf "subjectAltName=DNS:nas.xxx.de,DNS:nas.xxx.com" >> letsencrypt/openssl-csr-config.cnf
    openssl req -new -sha256 -key letsencrypt/keys/domain.key -subj "/" -reqexts SAN -config letsencrypt/openssl-csr-config.cnf > letsencrypt/domain.csr
    ```
4. `mv /etc/stunnel/stunnel.pem /etc/stunnel/stunnel.pem.orig` (backup)

5. Run `renew_certificate.sh`

6. `account.key`, `domain.key` and even the csr (according to acme-tiny readme) can be reused, so just create a cronjob to run `renew_certificate.sh` every night, which will renew your certificate if it has less than 30 days left

    Add this to `/etc/config/crontab`:
    ```
    30 3 * * * /share/CE_CACHEDEV1_DATA/qnap-letsencrypt/renew_certificate.sh >> /share/CE_CACHEDEV1_DATA/qnap-letsencrypt/renew_certificate.log 2>&1
    ```

    Then run:
    ```
    crontab /etc/config/crontab
    /etc/init.d/crond.sh restart
    ```

### FAQ
#### Why is xxx not working after a reboot?
Anything that's added to one of the following directories is gone after a reboot:
  - `/root/` (`.gitconfig`, `.bash_history`)
  - `/share/` (with the exception of anything added to drives mounted there)
  - `/etc/ssl/`, `/etc/ssl/certs`

Additionally, the following is not surviving a reboot:
  - Cronjobs added using `crontab -e`

Note that qpkgs get installed to `/share/CE_CACHEDEV1_DATA/.qpkg`. Due to this they are only available after unlocking your disks encryption.

#### What is actually surving a reboot?
  - Anything that is on a drive, e.g. `/share/CE_CACHEDEV1_DATA/`
  - `/etc/stunnel/stunnel.pem` (the ssl certificate used for the webinterface) seems to survive a reboot

#### What about surviving an firmware update?
In my tests, all the above applied. I couldn't see anything additional being lost.

#### How to generate content of `/etc/ssl/certs`?
This is only documented as it was part of my research and is not needed for the letsencrypt certificate generation.

First, install Perl from the qnap app manager.

Then, in your qnap-letsencrypt directory:
```
mkdir certs
cat cacert.pem | awk 'split_after==1{n++;split_after=0} /-----END CERTIFICATE-----/ {split_after=1} {print > "certs/cert" n ".pem"}'
wget --ca-certificate cacert.pem https://raw.githubusercontent.com/ChatSecure/OpenSSL/master/tools/c_rehash
/opt/bin/perl c_rehash certs
export SSL_CERT_FILE=`pwd`/cacert.pem
```

You can now copy this to `/etc/ssl/certs`. Alternatively, you can do this directly in `/etc/ssl/certs` if you want to, but remember, that it is lost after a reboot.

#### How to test whether a python script fails due to missing ca certificates

```
from urllib.request import urlopen # Python 3
urlopen("https://google.com")
```

If you get this:
```
urllib2.URLError: <urlopen error [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed (_ssl.c:581)>
```

there is something wrong.

Remember to run `export SSL_CERT_FILE=cacert.pem` though, as it is done in `renew_certificates.sh`
#### How can I contribute anything to this project?
Please open a pull request!

#### You want to buy me a coffee?
Feel free to send a donation this way: https://www.paypal.me/qnapletsencrypt

#### What license is this code licensed under?
GPLv2
