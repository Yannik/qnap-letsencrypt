# Let's Encrypt on QNAP
## Install Instructions
### NAS Setup
1. Login to your NAS and make sure the following Apps are installed:
	  * Git
	  * Python
2. Create a folder to store the scripts in /share (Same level as the default Multimedia,Public folders)
3. Copy `init.sh` and `renew_certificate.sh` to this folder. For example, I will use `/share/scripts`

### Setting up a valid ca-bundle and cloning this repo
1. on your local pc with an intact certificate store, run
        ````
        curl -s https://curl.haxx.se/ca/cacert.pem | sha1sum
        ```

2. on your nas, in the directory you want to install qnap-letsencrypt in, run
        ```
        wget --no-check-certificate https://curl.haxx.se/ca/cacert.pem
        sha1sum cacert.pem
        ```

3. compare the hashes obtained in step 1 and 2, they must match.

4. on your nas, in the directory you were in before
        ```
        git config --global http.sslVerify true
        git config --global http.sslCAinfo `pwd`/cacert.pem
        git clone https://github.com/Yannik/qnap-letsencrypt.git
        mv cacert.pem qnap-letsencrypt
        cd qnap-letsencrypt
        git config --global http.sslCAinfo `pwd`/cacert.pem
        ```

### Setting up qnap-letsencrypt
1. run `init.sh`

2. create a Certificate Signing Request(csr):

	**single domain cert:** (replace nas.xxx.de with your domain name)
	```
	openssl req -new -sha256 -key keys/domain.key -subj "/CN=nas.xxx.de" > domain.csr
	```

	**multiple domain cert:** (replace nas.xxx.de and xxx.myqnapcloud.com with your domain name)
	```
	cp /etc/ssl/openssl.cnf openssl-csr-config.cnf
	printf "[SAN]\nsubjectAltName=DNS:nas.xxx.de,DNS:xxx.myqnapcloud.com" >> openssl-csr-config.cnf
	openssl req -new -sha256 -key keys/domain.key -subj "/" -reqexts SAN -config openssl-csr-config.cnf > domain.csr
	```
4. `mv /etc/stunnel/stunnel.pem /etc/stunnel/stunnel.pem.orig` (backup)

5. run `renew_certificate.sh`

6. account.key, domain.key and even the csr (according to acme-tiny readme) can be reused, so just create a cronjob to run `renew_certificate.sh` every night (certificate will only be renewed if <30 days left)
    example: (make sure to use crontab -e!)
    ```
    30 3 * * * cd /share/scripts && /share/scripts/renew_certificate.sh &>> /share/scripts/renew_certificate.log
    ```
    this should hopefully persist a reboot...
    just to be sure, restart crond: `/etc/init.d/crond.sh restart` 
