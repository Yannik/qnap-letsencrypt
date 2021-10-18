#!/usr/bin/env bash

# Constants to customize
# Custom HTTP port on QNAP for acme challenge,
# in your router external HTTP port 80 must then be forwarded to this port
RENEWAL_HTTP_PORT=80
# Keep this key at a safe location
PRIVATE_DOMAIN_KEY="letsencrypt/keys/domain.key"

usage()
{
  echo "Usage:   renew_certificate.sh [-f|--force]"
  echo "Options:"
  echo "  -f [ --force ]        Force certificate renewal"
  echo "  -? [ --help ]         Display help message"
}

# Function to print failure message
msg_renewal_failed() {
  echo ""
  echo "***********************************"
  echo "*** Renewing certificate failed ***"
  echo "***********************************"
}

error_cleanup() {
  echo "An error occured. Restoring system state..."
  cleanup
  msg_renewal_failed
}

cleanup() {
  [ -n "$pid" ] && kill -9 $pid
  rm -rf tmp-webroot
  /etc/init.d/stunnel.sh start
  /etc/init.d/Qthttpd.sh start
}


SCRIPT_DIR=$(dirname "$(readlink -f -- "$0")")
cd "$SCRIPT_DIR"

FORCE_RENEWAL=0
for i in "$@"
do
  case $i in
    # display usage
    "-?"|"--help")
    usage
    exit
    ;;
    # force renewal
    "-f"|"--force")
    FORCE_RENEWAL=1
    shift
    ;;
    *)
    # argument error
    echo "ArgumentError: Unknown option $i"
    exit 1
    ;;
  esac
done

if [ $FORCE_RENEWAL -eq 0 ]; then
  # do nothing if certificate is valid for more than 30 days (30*24*60*60)
  echo "Checking whether to renew certificate on $(date -R)..."
  [ -s letsencrypt/signed.crt ] && openssl x509 -noout -in letsencrypt/signed.crt -checkend 2592000
  if [ "$?" -eq "0" ]; then
    echo "Done! Certificate valid for at least 30 days."
    exit
  fi
fi

if python3 -c "import http.server" 2> /dev/null; then
    PYTHON=python3
elif "$(/sbin/getcfg QPython3 Install_Path -f /etc/config/qpkg.conf)/bin/python3" -c "import http.server" 2> /dev/null; then
    PYTHON="$(/sbin/getcfg QPython3 Install_Path -f /etc/config/qpkg.conf)/bin/python3"
elif "$(/sbin/getcfg Python3 Install_Path -f /etc/config/qpkg.conf)/python3/bin/python3" -c "import http.server" 2> /dev/null; then
  PYTHON="$(/sbin/getcfg Python3 Install_Path -f /etc/config/qpkg.conf)/python3/bin/python3"
elif "$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf)/bin/python3" -c "import http.server" 2> /dev/null; then
  PYTHON="$(/sbin/getcfg Entware Install_Path -f /etc/config/qpkg.conf)/bin/python3"
else
  echo "Error: You need to install the Python 3.5 qpkg!"
  msg_renewal_failed
  exit 1
fi

set -o errexit
trap error_cleanup ERR

echo "Renewing certificate..."
[ -e .git ] && echo "qnap-letsencrypt version: $(git rev-parse --short HEAD)"
echo "Using python path: $PYTHON"
echo "Stopping Qthttpd hogging port 80..."

/etc/init.d/Qthttpd.sh stop

lsof -i tcp:$RENEWAL_HTTP_PORT -a -c python -t | xargs -r -I {} sh -c 'echo "Killing old python process {} hogging port $RENEWAL_HTTP_PORT" && kill {} && sleep 1'

mkdir -p tmp-webroot/.well-known/acme-challenge
cd tmp-webroot
"$PYTHON" ../HTTPServer.py $RENEWAL_HTTP_PORT &
pid=$!
cd ..
echo "Started Python HTTP server on port $RENEWAL_HTTP_PORT with pid $pid."

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
cat "$PRIVATE_DOMAIN_KEY" letsencrypt/chained.pem > /etc/stunnel/stunnel.pem
cp letsencrypt/intermediate.pem /etc/stunnel/uca.pem

# FTP
cp "$PRIVATE_DOMAIN_KEY" /etc/config/stunnel/backup.key
cp letsencrypt/signed.crt /etc/config/stunnel/backup.cert
if pidof proftpd > /dev/null; then
  echo "Restarting FTP..."
  /etc/init.d/ftp.sh restart || true
fi

echo "Done! Service startup and cleanup will follow now..."

cleanup
