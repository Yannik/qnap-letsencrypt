#!/bin/bash
set -o errexit

trap cleanup ERR

# Obtain base dir no matter this script is running with absolute or relative path
mydir () {
     SOURCE="${BASH_SOURCE[0]}"
     # While $SOURCE is a symlink, resolve it.
	 # Very possible when qnap-letsencrypt is put at shared folders.
     while [ -h "$SOURCE" ]; do
          DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
          SOURCE="$( readlink "$SOURCE" )"
          # If $SOURCE was a relative symlink (so no "/" as prefix, need to resolve it relative to the symlink base directory
          [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
     done
     DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
     echo "$DIR"
}

cleanup() {
  echo "An error occured. Restoring system state."
  # Force cd again to the root folder of letsencrypt to prevent accident.
  cd "$(mydir)"
  [ -n "$pid" ] && kill -9 $pid
  rm -rf tmp-webroot
  /etc/init.d/stunnel.sh start
  /etc/init.d/Qthttpd.sh start
}

# do nothing if certificate is valid for more than 30 days (30*24*60*60)
echo "Checking whether to renew certificate on $(date -R)"
[ -s letsencrypt/signed.crt ] && openssl x509 -noout -in letsencrypt/signed.crt -checkend 2592000 && exit

if python -c "import SimpleHTTPServer" 2> /dev/null; then
    PYTHON=python
elif "$(/sbin/getcfg Python Install_Path -f /etc/config/qpkg.conf)/bin/python2" -c "import SimpleHTTPServer" 2> /dev/null; then
    PYTHON="$(/sbin/getcfg Python Install_Path -f /etc/config/qpkg.conf)/bin/python2"
elif "$(/sbin/getcfg Python Install_Path -f /etc/config/qpkg.conf)/src/bin/python2" -c "import SimpleHTTPServer" 2> /dev/null; then
    PYTHON="$(/sbin/getcfg Python Install_Path -f /etc/config/qpkg.conf)/src/bin/python2"
elif "$(/sbin/getcfg Python3 Install_Path -f /etc/config/qpkg.conf)/python3/bin/python3" -c "import http.server" 2> /dev/null; then
    PYTHON="$(/sbin/getcfg Python3 Install_Path -f /etc/config/qpkg.conf)/python3/bin/python3"
elif "$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf)/bin/python" -c "import SimpleHTTPServer" 2> /dev/null; then
    PYTHON="$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf)/bin/python"
elif "$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf)/bin/python3" -c "import http.server" 2> /dev/null; then
    PYTHON="$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf)/bin/python3"
else
    echo "Error: You need to install the python 2.7 or 3.5 qpkg!"
    exit 1
fi

# cd to the location of letsencrypt's script. So incoming relative path will work normally.
cd "$(mydir)"

echo "Renewing certificate..."
echo "Stopping Qthttpd hogging port 80.."

/etc/init.d/Qthttpd.sh stop

echo "Killing old python processes hogging port 80"
lsof -i tcp:80 -a -c python -t | xargs --no-run-if-empty kill

mkdir -p tmp-webroot/.well-known/acme-challenge
cd tmp-webroot
"$PYTHON" ../HTTPServer.py &
pid=$!
cd ..
echo "Started python HTTP server with pid $pid"

export SSL_CERT_FILE=cacert.pem
"$PYTHON" acme-tiny/acme_tiny.py --account-key letsencrypt/account.key --csr letsencrypt/domain.csr --acme-dir tmp-webroot/.well-known/acme-challenge > letsencrypt/signed.crt.tmp
mv letsencrypt/signed.crt.tmp letsencrypt/signed.crt
echo "Downloading intermediate certificate..."
wget --no-verbose --secure-protocol=TLSv1_2 -O - https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem > letsencrypt/intermediate.pem
cat letsencrypt/signed.crt letsencrypt/intermediate.pem > letsencrypt/chained.pem

echo "Stopping stunnel and setting new stunnel certificates..."
/etc/init.d/stunnel.sh stop
cat letsencrypt/keys/domain.key letsencrypt/chained.pem > /etc/stunnel/stunnel.pem
cp letsencrypt/intermediate.pem /etc/stunnel/uca.pem

echo "Done! Service startup and cleanup will follow now..."

cleanup
