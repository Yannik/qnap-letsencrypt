# Let's Encrypt on QNAP
## Install Instructions
### NAS Setup
1. Make sure your NAS is reachable from the public internet under the domain you want to get a certificate for on port 80.
   
   If you use port forwarding, forward port 80 of the internet side of the router to port 80 on the nas.
2. Create a folder to store qnap-letsencrypt in under `/share/YOUR_DRIVE/`. Do not create it directly in `/share/`, as it will be lost after a reboot!

### Installing git and python
1. [Install entware](https://github.com/Entware/Entware/wiki/Install-on-QNAP-NAS).
2. Update entware package list: `opkg update`
3. Install git: `opkg install git git-http`
4. Install python: `opkg install python3`

If you don't want to install entware, you can also try the git / python packages from qnap store. However, these are often incomplete (for example: compiled without ssl or ipv6 support), so no support is provided if you don't use entware.

### Cloning this repo
1. On your nas, in the directory you want to install qnap-letsencrypt in, run
    ```
    git clone https://github.com/Yannik/qnap-letsencrypt.git
    cd qnap-letsencrypt
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

#### How can I contribute anything to this project?
Please open a pull request!

#### You want to buy me a coffee?
Feel free to send a donation this way: https://www.paypal.me/qnapletsencrypt

#### What license is this code licensed under?
GPLv2
