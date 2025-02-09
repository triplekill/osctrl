#!/usr/bin/env bash
#
# Provisioning script for osctrl
#
# Usage: provision.sh [-h|--help] [PARAMETER [ARGUMENT]] [PARAMETER [ARGUMENT]] ...
#
# Parameters:
#   -h, --help            Shows this help message and exit.
#   -m MODE, --mode MODE  Mode of operation. Default value is dev
#   -t TYPE, --type TYPE  Type of certificate to use. Default value is self
#   -p PART, --part PART  Part of the service. Default is all
#
# Arguments for MODE:
#   dev     Provision will run in development mode. Certificate will be self-signed.
#   prod    Provision will run in production mode.
#   update  Provision will update the service running in the machine.
#
# Arguments for TYPE:
#   self    Provision will use a self-signed TLS certificate that will be generated.
#   own     Provision will use the TLS certificate provided by the user.
#   certbot Provision will generate a TLS certificate using letsencrypt/certbot. More info here: https://certbot.eff.org/
#
# Argument for PART:
#   admin   Provision will deploy only the admin interface.
#   tls     Provision will deploy only the TLS endpoint.
#   all     Provision will deploy both the admin and the TLS endpoint.
#
# Optional Parameters:
#   --public-tls-port PORT      Port for the TLS endpoint service. Default is 443
#   --public-admin-port PORT    Port for the admin service. Default is 8443
#   --private-tls-port PORT     Port for the TLS endpoint service. Default is 9000
#   --private-admin-port PORT   Port for the admin service. Default is 9001
#   --tls-hostname HOSTNAME     Hostname for the TLS endpoint service. Default is 127.0.0.1
#   --admin-hostname HOSTNAME   Hostname for the admin service. Default is 127.0.0.1
#   -X PASS     --password      Force the admin password for the admin interface. Default is random
#   -U          --update        Pull from master and sync files to the current folder
#   -k PATH     --keyfile PATH  Path to supplied TLS key file
#   -c PATH     --certfile PATH Path to supplied TLS server PEM certificate(s) bundle
#   -d DOMAIN   --domain DOMAIN Domain for the TLS certificate to be generated using letsencrypt
#   -e EMAIL    --email EMAIL   Domain for the TLS certificate to be generated using letsencrypt
#   -s PATH     --source PATH   Path to code. Default is /vagrant
#   -S PATH     --dest PATH     Path to binaries. Default is /opt/osctrl
#   -n          --nginx         Install and configure nginx as TLS termination
#   -P          --postgres      Install and configure PostgreSQL as backend
#   -M          --metrics       Install and configure all services for metrics (InfluxDB + Telegraf + Grafana)
#   -E          --enroll        Enroll the serve into itself using osquery. Default is disabled
#
# Examples:
#   Provision service in development mode, code is in /vagrant and both admin and tls:
#     provision.sh -m dev -s /vagrant -p all
#   Provision service in production mode using my own certificate and only with TLS endpoint:
#     provision.sh -m prod -t own -k /etc/certs/my.key -c /etc/certs/cert.crt -p tls
#   Update service in development mode and running admin only from /home/foobar/osctrl:
#     provision.sh -m dev -U -s /home/foobar/osctrl -p admin
#

# Before we begin...
_START_TIME=$(date +%s)

# Show an informational log message
#   string  message_to_display
function log() {
  echo "[+] $1"
}

# Show an error log message
#   string  message_to_display
function _log() {
  echo "[!] $1"
}

# Noooooo Error!
OHNOES=41414141

# How does it work?
function usage() {
  printf "\nUsage: %s [-h|--help] [PARAMETER [ARGUMENT]] [PARAMETER [ARGUMENT]] ...\n" "${0}"
  printf "\nParameters:\n"
  printf "  -h, --help \t\tShows this help message and exit.\n"
  printf "  -m MODE, --mode MODE \tMode of operation. Default value is dev\n"
  printf "  -t TYPE, --type TYPE \tType of certificate to use. Default value is self\n"
  printf "  -p PART, --part PART \tPart of the service. Default is all\n"
  printf "\nArguments for MODE:\n"
  printf "  dev \t\tProvision will run in development mode. Certificate will be self-signed.\n"
  printf "  prod \t\tProvision will run in production mode.\n"
  printf "  update \tProvision will update the service running in the machine.\n"
  printf "\nArguments for TYPE:\n"
  printf "  self \t\tProvision will use a self-signed TLS certificate that will be generated.\n"
  printf "  own \t\tProvision will use the TLS certificate provided by the user.\n"
  printf "  certbot \tProvision will generate a TLS certificate using letsencrypt/certbot. More info here: https://certbot.eff.org/\n"
  printf "\nArguments for PART:\n"
  printf "  admin \tProvision will deploy only the admin interface.\n"
  printf "  tls \t\tProvision will deploy only the TLS endpoint.\n"
  printf "  all \t\tProvision will deploy both the admin and the TLS endpoint.\n"
  printf "\nOptional Parameters:\n"
  printf "  --public-tls-port PORT \tPort for the TLS endpoint service. Default is 443\n"
  printf "  --public-admin-port PORT \tPort for the admin service. Default is 8443\n"
  printf "  --private-tls-port PORT \tPort for the TLS endpoint service. Default is 9000\n"
  printf "  --private-admin-port PORT \tPort for the admin service. Default is 9001\n"
  printf "  --tls-hostname HOSTNAME \tHostname for the TLS endpoint service. Default is 127.0.0.1\n"
  printf "  --admin-hostname HOSTNAME \tHostname for the admin service. Default is 127.0.0.1\n"
  printf "  -X PASS     --password \tForce the admin password for the admin interface. Default is random\n"
  printf "  -U          --update \t\tPull from master and sync files to the current folder\n"
  printf "  -c PATH     --certfile PATH \tPath to supplied TLS server PEM certificate(s) bundle\n"
  printf "  -d DOMAIN   --domain DOMAIN \tDomain for the TLS certificate to be generated using letsencrypt\n"
  printf "  -e EMAIL    --email EMAIL \tDomain for the TLS certificate to be generated using letsencrypt\n"
  printf "  -s PATH     --source PATH \tPath to code. Default is /vagrant\n"
  printf "  -S PATH     --dest PATH \tPath to binaries. Default is /opt/osctrl\n"
  printf "  -n          --nginx \t\tInstall and configure nginx as TLS termination\n"
  printf "  -P          --postgres \tInstall and configure PostgreSQL as backend\n"
  printf "  -M          --metrics \tInstall and configure all services for metrics (InfluxDB + Telegraf + Grafana)\n"
  printf "  -E          --enroll  \tEnroll the serve into itself using osquery. Default is disabled\n"
  printf "\nExamples:\n"
  printf "  Provision service in development mode, code is in /vagrant and both admin and tls:\n"
  printf "\t%s -m dev -s /vagrant -p all\n" "${0}"
  printf "  Provision service in production mode using my own certificate and only with TLS endpoint:\n"
  printf "\t%s -m prod -t own -k /etc/certs/my.key -c /etc/certs/cert.crt -p tls\n" "${0}"
  printf "  Update service in development mode and running admin only from /home/foobar/osctrl:\n"
  printf "\t%s -U -s /home/foobar/osctrl -p admin\n" "${0}"
  printf "\n"
}

# We want the provision script to fail as soon as there are any errors
set -e

# Values not intended to change
TLS_COMPONENT="tls"
ADMIN_COMPONENT="admin"
TLS_CONF="$TLS_COMPONENT.json"
ADMIN_CONF="$ADMIN_COMPONENT.json"
DB_CONF="db.json"
SERVICE_TEMPLATE="service.json"
DB_TEMPLATE="db.json"
SYSTEMD_TEMPLATE="systemd.service"

# Default values for arguments
SHOW_USAGE=false
MODE="dev"
TYPE="self"
PART="all"
KEYFILE=""
CERTFILE=""
DOMAIN=""
EMAIL=""
METRICS=false
ENROLL=false
UPDATE=false
NGINX=false
POSTGRES=false
SOURCE_PATH=/vagrant
DEST_PATH=/opt/osctrl

# Backend values
_DB_HOST="localhost"
_DB_NAME="osctrl"
_DB_SYSTEM_USER="postgres"
_DB_USER="osctrl"
_DB_PASS="osctrl"
_DB_PORT="5432"

# TLS Service
_T_INT_PORT="9000"
_T_PUB_PORT="443"
_T_HOST="127.0.0.1"
_T_AUTH="none"
_T_LOGGING="db"

# Admin Service
_A_INT_PORT="9001"
_A_PUB_PORT="8443"
_A_HOST="127.0.0.1"
_A_AUTH="db"
_A_LOGGING="db"

# Default admin credentials with random password
_ADMIN_USER="admin"
_ADMIN_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1 | md5sum | cut -d " " -f1)

# Arrays with valid arguments
VALID_MODE=("dev" "prod" "update")
VALID_TYPE=("self" "own" "certbot")
VALID_PART=("$TLS_COMPONENT" "$ADMIN_COMPONENT" "all")

# Extract arguments
ARGS=$(getopt -n "$0" -o hm:t:p:UPk:nMEc:d:e:s:S:X: -l "help,mode:,type:,part:,public-tls-port:,private-tls-port:,public-admin-port:,private-admin-port:,tls-hostname:,admin-hostname:,update,keyfile:,nginx,postgres,metrics,enroll,certfile:,domain:,email:,source:,dest:,password:" -- "$@")

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$ARGS"

while true; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -m|--mode)
      GIVEN_ARG=$2
      if [[ "${VALID_MODE[@]}" =~ "${GIVEN_ARG}" ]]; then
        SHOW_USAGE=false
        MODE=$2
        shift 2
      else
        _log "Invalid mode"
        usage
        exit $OHNOES
      fi
      ;;
    -t|--type)
      GIVEN_ARG=$2
      if [[ "${VALID_TYPE[@]}" =~ "${GIVEN_ARG}" ]]; then
        SHOW_USAGE=false
        TYPE=$2
        shift 2
      else
        _log "Invalid certificate type"
        usage
        exit $OHNOES
      fi
      ;;
    -p|--part)
      GIVEN_ARG=$2
      if [[ "${VALID_PART[@]}" =~ "${GIVEN_ARG}" ]]; then
        SHOW_USAGE=false
        PART=$2
        shift 2
      else
        _log "Invalid part"
        usage
        exit $OHNOES
      fi
      ;;
    --public-tls-port)
      SHOW_USAGE=false
      _T_PUB_PORT=$2
      shift 2
      ;;
    --private-tls-port)
      SHOW_USAGE=false
      _T_INT_PORT=$2
      shift 2
      ;;
    --public-admin-port)
      SHOW_USAGE=false
      _A_PUB_PORT=$2
      shift 2
      ;;
    --private-admin-port)
      SHOW_USAGE=false
      _A_INT_PORT=$2
      shift 2
      ;;
    --tls-hostname)
      SHOW_USAGE=false
      _T_HOST=$2
      shift 2
      ;;
    --admin-hostname)
      SHOW_USAGE=false
      _A_HOST=$2
      shift 2
      ;;
    -U|--update)
      SHOW_USAGE=false
      UPDATE=true
      shift
      ;;
    -n|--nginx)
      SHOW_USAGE=false
      NGINX=true
      shift
      ;;
    -P|--postgres)
      SHOW_USAGE=false
      POSTGRES=true
      shift
      ;;
    -M|--metrics)
      SHOW_USAGE=false
      METRICS=true
      shift
      ;;
    -E|--enroll)
      SHOW_USAGE=false
      ENROLL=true
      shift
      ;;
    -k|--keyfile)
      SHOW_USAGE=false
      KEYFILE=$2
      shift 2
      ;;
    -c|--certfile)
      SHOW_USAGE=false
      CERTFILE=$2
      shift 2
      ;;
    -d|--domain)
      SHOW_USAGE=false
      DOMAIN=$2
      shift 2
      ;;
    -e|--email)
      SHOW_USAGE=false
      EMAIL=$2
      shift 2
      ;;
    -s|--source)
      SHOW_USAGE=false
      SOURCE_PATH=$2
      shift 2
      ;;
    -S|--dest)
      SHOW_USAGE=false
      DEST_PATH=$2
      shift 2
      ;;
    -X|--password)
      SHOW_USAGE=false
      _ADMIN_PASS=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
  esac
done

# No parameters, show usage
if [[ "$SHOW_USAGE" == true ]]; then
  _log "Parameters are needed!"
  usage
  exit $OHNOES
fi

# Include functions
source "$SOURCE_PATH/deploy/lib.sh"

# Detect Linux distro
if [[ -f "/etc/debian_version" ]]; then
  DISTRO="ubuntu"
elif [[ -f "/etc/centos-release" ]]; then
  DISTRO="centos"
fi

# Update service
if [[ "$UPDATE" == true ]]; then
  _log "Update not implemented yet!"
  exit $OHNOES
fi

# We are provisioning a new machine
log ""
log ""
log "Provisioning [ osctrl ][ $PART ] for $DISTRO"
log ""
log "  -> [$MODE] mode and with [$TYPE] certificate"
log ""
if [[ "$PART" == "all" ]] || [[ "$PART" == "$TLS_COMPONENT" ]]; then
  log "  -> Deploying TLS service for ports $_T_PUB_PORT:$_T_INT_PORT"
  log "  -> Hostname for TLS endpoint: $_T_HOST"
fi
log ""
if [[ "$PART" == "all" ]] || [[ "$PART" == "$ADMIN_COMPONENT" ]]; then
  log "  -> Deploying Admin service for ports $_A_PUB_PORT:$_A_INT_PORT"
  log "  -> Hostname for admin: $_A_HOST"
fi
log ""
log ""

# Update distro
package_repo_update

# Required packages
if [[ "$DISTRO" == "ubuntu" ]]; then
  package build-essential
fi
package sudo
package git
package wget
package curl
package gcc
package make
package openssl
package tmux
package bc

# nginx as TLS termination
if [[ "$NGINX" == true ]]; then
  # Some static values for now that can be turned into arguments eventually
  NGINX_PATH="/etc/nginx"
  if [[ "$DISTRO" == "centos" ]]; then
    package epel-release
  fi
  package nginx

  _certificate_name="osctrl"
  _certificates_dir="$NGINX_PATH/certs"
  sudo mkdir -p "$_certificates_dir"

  _cert_file="$_certificates_dir/$_certificate_name.crt"
  _key_file="$_certificates_dir/$_certificate_name.key"
  _dh_file="$_certificates_dir/dhparam.pem"
  _dh_bits="1024"

  # Self-signed certificates for dev
  if [[ "$MODE" == "dev" ]]; then
    self_certificates_nginx "$_certificates_dir" "$_certificate_name"
  fi
  # Certbot certificates for prod and 4096 dhparam file
  if [[ "$MODE" == "prod" ]]; then
    _dh_bits="4096"
    #certbot_certificates_nginx "$_certificates_dir" "$_certificate_name" "$EMAIL" "$DOMAIN"
    # FIXME: REMEMBER GENERATE THE CERTIFICATES MANUALLY!
    log "************** REMEMBER GENERATE THE CERTIFICATES MANUALLY **************"
    #sudo cp "/etc/letsencrypt/archive/osctrl/fullchain1.pem" "$_cert_file"
    #sudo cp "/etc/letsencrypt/archive/osctrl/privkey1.pem" "$_key_file"
  fi

  # Diffie-Hellman parameter for DHE ciphersuites
  log "Generating dhparam.pem with $_dh_bits bits... It may take a while"
  sudo openssl dhparam -out "$_dh_file" $_dh_bits &>/dev/null

  # Configuration for nginx
  if [[ "$DISTRO" == "ubuntu" ]]; then
    nginx_main "$SOURCE_PATH/deploy/nginx/nginx.conf" "nginx.conf" "www-data" "/etc/nginx/modules-enabled/*.conf" "$NGINX_PATH"
  elif [[ "$DISTRO" == "centos" ]]; then
    nginx_main "$SOURCE_PATH/deploy/nginx/nginx.conf" "nginx.conf" "nginx" "/usr/share/nginx/modules/*.conf" "$NGINX_PATH"
    # SELinux
    log "Enabling httpd in SELinux"
    sudo setsebool -P httpd_can_network_connect 1
  fi

  # Configuration for TLS service
  nginx_service "$SOURCE_PATH/deploy/nginx/ssl.conf" "$_cert_file" "$_key_file" "$_dh_file" "$_T_PUB_PORT" "$_T_INT_PORT" "tls.conf" "$NGINX_PATH"

  # Configuration for Admin service
  nginx_service "$SOURCE_PATH/deploy/nginx/ssl.conf" "$_cert_file" "$_key_file" "$_dh_file" "$_A_PUB_PORT" "$_A_INT_PORT" "admin.conf" "$NGINX_PATH"

  # Restart nginx
  sudo nginx -t
  sudo service nginx restart
fi

# PostgreSQL - Backend
if [[ "$POSTGRES" == true ]]; then
  POSTGRES_CONF="$SOURCE_PATH/deploy/postgres/pg_hba.conf"
  if [[ "$DISTRO" == "ubuntu" ]]; then
    package postgresql
    package postgresql-contrib
    POSTGRES_SERVICE="postgresql"
    POSTGRES_HBA="/etc/postgresql/10/main/pg_hba.conf"
    POSTGRES_PSQL="/usr/lib/postgresql/10/bin/psql"
  elif [[ "$DISTRO" == "centos" ]]; then
    sudo rpm -Uvh "http://yum.postgresql.org/9.6/redhat/rhel-7-x86_64/pgdg-redhat96-9.6-3.noarch.rpm"
    package postgresql96-server
    package postgresql96-contrib
    sudo /usr/pgsql-9.6/bin/postgresql96-setup initdb
    POSTGRES_SERVICE="postgresql-9.6"
    POSTGRES_HBA="/var/lib/pgsql/9.6/data/pg_hba.conf"
    POSTGRES_PSQL="/usr/pgsql-9.6/bin/psql"
  fi
  configure_postgres "$POSTGRES_CONF" "$POSTGRES_SERVICE" "$POSTGRES_HBA"
  db_user_postgresql "$_DB_NAME" "$_DB_SYSTEM_USER" "$_DB_USER" "$_DB_PASS" "$POSTGRES_PSQL"
fi

# Metrics - InfluxDB + Telegraf + Grafana
if [[ "$METRICS" == true ]]; then
  if [[ "$DISTRO" == "ubuntu" ]]; then
    install_influx_telegraf
    configure_influx_telegraf
    install_grafana
    configure_grafana
  elif [[ "$DISTRO" == "centos" ]]; then
    log "Not ready yet to install metrics for CentOS"
  fi
fi

# Golang
# package golang-go
install_go_12

# Prepare destination and configuration folder
sudo mkdir -p "$DEST_PATH/config"

# Generate DB configuration file for services
configuration_db "$SOURCE_PATH/deploy/$DB_TEMPLATE" "$DEST_PATH/config/$DB_CONF" "$_DB_HOST" "$_DB_PORT" "$_DB_NAME" "$_DB_USER" "$_DB_PASS" "sudo"

# Build code
cd "$SOURCE_PATH"
make clean

if [[ "$PART" == "all" ]] || [[ "$PART" == "$TLS_COMPONENT" ]]; then
  # Build TLS service
  make tls

  # Configuration file generation for TLS service
  configuration_service "$SOURCE_PATH/deploy/$SERVICE_TEMPLATE" "$DEST_PATH/config/$TLS_CONF" "$_T_HOST|$_T_INT_PORT" "$TLS_COMPONENT" "127.0.0.1" "$_T_AUTH" "$_T_LOGGING" "sudo"

  # Prepare static files for TLS service
  _static_files "$MODE" "$SOURCE_PATH" "$DEST_PATH" "tls/scripts" "scripts"

  # Prepare plugins
  make plugins
  sudo ln -fs "$SOURCE_PATH/plugins" "$DEST_PATH/plugins"

  # Systemd configuration for TLS service
  _systemd "osctrl" "osctrl" "osctrl-tls" "$SOURCE_PATH" "$DEST_PATH"
fi

if [[ "$PART" == "all" ]] || [[ "$PART" == "$ADMIN_COMPONENT" ]]; then
  # Build Admin service
  make admin

  # Configuration file generation for Admin service
  configuration_service "$SOURCE_PATH/deploy/$SERVICE_TEMPLATE" "$DEST_PATH/config/$ADMIN_CONF" "$_A_HOST|$_A_INT_PORT" "$ADMIN_COMPONENT" "127.0.0.1" "$_A_AUTH" "$_A_LOGGING" "sudo"

  # Prepare data folder
  sudo mkdir -p "$DEST_PATH/data"

  # Prepare carved files folder
  sudo mkdir -p "$DEST_PATH/carved_files"
  sudo chown osctrl.osctrl "$DEST_PATH/carved_files"

  # Copy osquery tables JSON file
  sudo cp "$SOURCE_PATH/deploy/osquery/data/3.3.2.json" "$DEST_PATH/data"

  # Copy empty configuration
  sudo cp "$SOURCE_PATH/deploy/osquery/osquery-empty.json" "$DEST_PATH/data"

  # Prepare static files for Admin service
  _static_files "$MODE" "$SOURCE_PATH" "$DEST_PATH" "admin/templates" "tmpl_admin"
  _static_files "$MODE" "$SOURCE_PATH" "$DEST_PATH" "admin/static" "static"

  # Static files will require internet connection (CSS + JS)
  sudo ln -fs "$SOURCE_PATH/cmd/admin/templates/components/page-head-online.html" "$DEST_PATH/tmpl_admin/components/page-head.html"
  sudo ln -fs "$SOURCE_PATH/cmd/admin/templates/components/page-js-online.html" "$DEST_PATH/tmpl_admin/components/page-js.html"

  # Systemd configuration for Admin service
  _systemd "osctrl" "osctrl" "osctrl-admin" "$SOURCE_PATH" "$DEST_PATH"
fi

# Compile CLI
make cli

# Install CLI
DEST="$DEST_PATH" make install_cli

# If we are in dev, create environment and enroll host
if [[ "$MODE" == "dev" ]]; then
  log "Creating environment for dev"
  __db_conf="$DEST_PATH/config/$DB_CONF"
  __osquery_dev="$SOURCE_PATH/deploy/osquery/osquery-dev.json"
  __osctrl_crt="/etc/nginx/certs/osctrl.crt"
  "$DEST_PATH"/osctrl-cli -D "$__db_conf" environment add -n "dev" -host "$_T_HOST" -conf "$__osquery_dev" -crt "$__osctrl_crt"

  log "Checking if service is ready"
  while true; do
    _readiness=$(curl -k --write-out %{http_code} --head --silent --output /dev/null "https://$_T_HOST")
    if [[ "$_readiness" == "200" ]]; then
      log "Status $_readiness, service ready"
      break
    else
      log "Status $_readiness, not yet"
    fi
    sleep 1
  done

  if [[ "$ENROLL" == true ]]; then
    log "Adding host in dev environment"
    eval $( "$DEST_PATH"/osctrl-cli -D "$__db_conf" environment quick-add -n "dev" )
  fi
fi

# Create admin user
log "Creating admin user"
"$DEST_PATH"/osctrl-cli -D "$__db_conf" user add -u "$_ADMIN_USER" -p "$_ADMIN_PASS" -a -n Admin

# Ascii art is always appreciated
if [[ "$DISTRO" == "ubuntu" ]]; then
  set_motd_ubuntu "$SOURCE_PATH/deploy/motd-osctrl.sh"
elif [[ "$DISTRO" == "centos" ]]; then
  set_motd_centos "$SOURCE_PATH/deploy/motd-osctrl.sh"
fi

echo
log "Your osctrl is ready 👌🏽"
echo
if [[ "$MODE" == "dev" ]]; then
  log " -> https://$_A_HOST:$_A_PUB_PORT"
  echo
  log " -> 🔐 Credentials: $_ADMIN_USER / $_ADMIN_PASS"
  echo
fi

# Done
_END_TIME=$(date +%s)
_DIFFERENCE=$(echo "$_END_TIME-$_START_TIME" | bc)
_MINUTES="$(echo "$_DIFFERENCE/60" | bc) minutes"
_SECONDS="$(echo "$_DIFFERENCE%60" | bc) seconds"

echo
log "Completed in $_MINUTES and $_SECONDS"

exit 0

# kthxbai

# Standard deployment in a linux box would be like:
# ./deploy/provision.sh --nginx --postgres -p all --tls-hostname "dev.osctrl.net" --admin-hostname "dev.osctrl.net" -E
