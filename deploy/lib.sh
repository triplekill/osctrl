#!/usr/bin/env bash
#
# [ osctrl 🎛 ]: Provisioning script functions

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

function package_repo_update() {
  log "Running apt-get update"
  sudo DEBIAN_FRONTEND=noninteractive apt-get update
}

# Install a package in the system
#   string  package_name
function package() {
  if [[ -n "$(dpkg --get-selections | grep -P '^$1\s')" ]]; then
    log "$1 is already installed. skipping."
  else
    log "Installing $1"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install $1 -y --no-install-recommends
  fi
}

# Install several packages in the system
#   string  package_name0
#   string  package_name1
#   ...
#   string  package_nameN
function packages() {
  for i in "$@"; do 
    package "$i"
  done
}

# Add osquery repository for Ubuntu
function repo_osquery_ubuntu() {
  log "Adding osquery repository keys"
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1484120AC4E9F8A1A577AEEE97A80C63C9D8B80B
  
  log "Adding osquery repository"
  sudo add-apt-repository 'deb [arch=amd64] https://pkg.osquery.io/deb deb main'
}

# Install fpm to generate packages
function install_fpm() {
  log "Installing fpm dependencies"
  packages ruby ruby-dev rubygems build-essential

  log "Installing fpm"
  sudo gem install --no-ri --no-rdoc fpm
}

# Generate self-signed certificates
#   string  path_to_certs
#   string  certificate_name
function self_signed_cert() {
  local __certs=$1
  local __name=$2

  local __csr="$__certs/$__name.csr"
  local __devcert="$__certs/$__name.crt"
  local __devkey="$__certs/$__name.key"

  sudo openssl req -nodes -newkey rsa:2048 -keyout "$__devkey" -out "$__csr" -subj "/O=osctrl"
  sudo openssl x509 -req -days 365 -in "$__csr" -signkey "$__devkey" -out "$__devcert"
}

# Configure nginx for a service
#   string  configuration_template
#   string  certificate_file
#   string  certificate_key
#   string  certificate_dh
#   int     public_port
#   int     private_port
#   string  configuration_output
#   string  nginx_folder
function configure_nginx() {
  local __conf=$1
  local __cert=$2
  local __key=$3
  local __dh=$4
  local __pport=$5
  local __iport=$6
  local __out=$7
  local __nginx=$8

  cat "$__conf" | sed "s|PUBLIC_PORT|$__pport|g" | sed "s|CER_FILE|$__cert|g" | sed "s|KEY_FILE|$__key|g" | sed "s|DHPARAM_FILE|$__dh|g" | sed "s|PRIVATE_PORT|$__iport|g" | sudo tee "$__nginx/sites-available/$__out"

  sudo rm -f "$__nginx/sites-enabled/default"
  sudo ln -sf "$__nginx/sites-available/$__out" "$__nginx/sites-enabled/$__out"
}

# Generate self-signed certificates for nginx
#   string  certs_directory
#   string  certificate_name
function self_certificates_nginx() {
  local __certs_path=$1
  local __name=$2
  
  log "Deploying self-signed certificates"

  self_signed_cert "$__certs_path" "$__name"
}

# Generate certbot certificates for nginx
#   string  certs_directory
#   string  certificate_name
#   string  email_certbot
#   string  domain_certificate
function certbot_certificates_nginx() {
  local __certs_path=$1
  local __name=$2
  local __email=$3
  local __domain=$4
  local __cert="$__certs_path/$__name.crt"
  local __key="$__certs_path/$__name.key"

  log "Installing certbot components"

  package software-properties-common
  sudo add-apt-repository ppa:certbot/certbot -y
  package_repo_update
  package python-certbot-nginx

  # Just in case nginx is running
  sudo systemctl stop nginx

  # Generating certificate
  log "Generating certificate with certbot for $DOMAIN"
  sudo certbot -n --agree-tos --standalone certonly -m "$__email" -d "$__domain" --cert-name "$__name" --cert-path "$__cert" --key-path "$__key"
}

# Configuration file generation
#   string  conf_template
#   string  conf_destination
#   string  tls_host_port (host|port)
#   string  db_host
#   string  db_port
#   string  db_name
#   string  db_username
#   string  db_password
#   string  admin_host_port (host|port)
function configure_service() {
  local __conf=$1
  local __dest=$2
  local __tlshost=`echo $3 | cut -d"|" -f1`
  local __tlsport=`echo $3 | cut -d"|" -f2`
  local __dbhost=$4
  local __dbport=$5
  local __dbname=$6
  local __dbuser=$7
  local __dbpass=$8
  local __adminhost=`echo $9 | cut -d"|" -f1`
  local __adminport=`echo $9 | cut -d"|" -f2`

  log "Generating $__dest configuration"

  cat "$__conf" | sed "s|_TLS_PORT|$__tlsport|g" | sed "s|_TLS_HOST|$__tlshost|g" | sed "s|_DB_HOST|$__dbhost|g" | sed "s|_DB_PORT|$__dbport|g" | sed "s|_DB_NAME|$__dbname|g" | sed "s|_DB_USERNAME|$__dbuser|g" | sed "s|_DB_PASSWORD|$__dbpass|g" | sed "s|_ADMIN_PORT|$__adminport|g" | sed "s|_ADMIN_HOST|$__adminhost|g" | sudo tee "$__dest"
}

# Configure credentials
#   string  conf_template
#   string  conf_destination
#   string  admin_user
#   string  admin_pass
function configure_credentials() {
  local __conf=$1
  local __dest=$2
  local __adminuser=$3
  local __adminpass=$4

  log "Adding credentials to $__dest"

  cat "$__conf" | sed "s|_ADMIN_USER|$__adminuser|g" | sed "s|_ADMIN_PASS|$__adminpass|g" | sudo tee "$__dest"
}

# Enable service as systemd
#   string  service_user
#   string  service_name
#   string  path_to_code
#   string  path_destination
function _systemd() {
  local __user=$1
  local __server=$2
  local __path=$3
  local __dest=$4

  # Creating user for services
  if [[ $(grep -c "$__user" /etc/passwd) -eq 0 ]]; then
    sudo useradd "$__user" -s /sbin/nologin -M
  fi

  # Adding service
  sudo cp "$__path/deploy/$__server.service" /lib/systemd/system/.
  sudo chmod 755 "/lib/systemd/system/$__server.service"

  # Copying binaries
  sudo cp "$__path/$__server" "$__dest"

  # Enable and start service
  sudo systemctl enable "$__server.service"
  sudo systemctl start "$__server"
}

# Prepare service directories and copy static files
#   string  mode_of_operation
#   string  path_to_code
#   string  path_destination
function _static_files() {
  local __mode=$1
  local __path=$2
  local __dest=$3
  
  # Static files will be linked if we are in dev
  if [[ "$__mode" == "dev" ]]; then
    sudo ln -s "$__path/src/tls/templates" "$__dest/templates"
    sudo ln -s "$__path/src/tls/static" "$__dest/static"
  else
    sudo cp -R "$__path/src/tls/templates" "$__dest/templates"
    sudo cp -R "$__path/src/tls/static" "$__dest/static"
  fi
}

# Install PostgreSQL 10 in Ubuntu 16.04 (xenial)
#   string  PostgreSQL_conf_file_location
function install_postgresql10_xenial() {
  local __pgversion="10"
  local __pgconf=$1
  local __pgctl="/usr/lib/postgresql/10/bin/pg_ctl"
  
  repo_postgres_xenial

  package_repo_update
  
  package "postgresql-$__pgversion"
  
  configure_postgres "$__pgversion" "$__pgconf"
}

# Create empty DB and username
#   string  PostgreSQL_db_name
#   string  PostgreSQL_system_user
#   string  PostgreSQL_db_user
#   string  PostgreSQL_db_pass
function db_user_postgresql() {
  local __psql="/usr/lib/postgresql/10/bin/psql"
  local __pgdb=$1
  local __pguser=$2
  local __dbuser=$3
  local __dbpass=$4

  log "Creating user"
  local _dbstatementuser="CREATE USER $__dbuser;"
  sudo su - "$__pguser" -c "$__psql -c \"$_dbstatementuser\""

  log "Adding password to user"
  local _dbstatementpass="ALTER USER $__dbuser WITH ENCRYPTED PASSWORD '$__dbpass';"
  sudo su - "$__pguser" -c "$__psql -c \"$_dbstatementpass\""

  log "Creating new database"
  sudo su - "$__pguser" -c "$__psql -c 'ALTER ROLE $__dbuser WITH CREATEDB'"
  sudo su - "$__pguser" -c "$__psql -c 'CREATE DATABASE $__pgdb'"

  log "Granting privileges to user"
  local _dbstatementgrant="GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $__dbuser;"
  sudo su - "$__pguser" -c "$__psql -d $__pgdb -c '$_dbstatementgrant'"
}

# Create empty DB and import schema
#   string  PostgreSQL_db_name
#   string  PostgreSQL_system_user
#   string  PostgreSQL_db_schema_file
#   string  PostgreSQL_db_user
function schema_postgresql() {
  local __psql="/usr/lib/postgresql/10/bin/psql"
  local __pgdb=$1
  local __pguser=$2
  local __pgschema=$3
  local __dbuser=$4

  log "Importing schema $__pgschema"
  sudo su - "$__pguser" -c "$__psql -U $__dbuser -d $__pgdb -f $__pgschema"
}

# Add PostgreSQL repo in Ubuntu 16.04 (xenial)
function repo_postgres_xenial() {
  local __pgfile="/etc/apt/sources.list.d/pgdg.list"

  log "Adding PostgreSQL repository"
  if [[ ! -f "$__pgfile" ]]; then
    sudo add-apt-repository 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main'
  else
    log "Already added"
  fi
  log "Adding PostgreSQL repository keys"
  wget -q -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
}

# Configure PostgreSQL
#   string  postgres_conf_file_location
function configure_postgres() {
  local __conf=$1

  log "PostgreSQL permissions"
  
  sudo cp "$__conf" "/etc/postgresql/10/main/pg_hba.conf"
  
  sudo systemctl restart postgresql
  sudo systemctl enable postgresql
}

# Customize the MOTD in Ubuntu
#   string  path_to_motd_script
function set_motd_ubuntu() {
  local __motd=$1

  # If the cloudguest MOTD exists, disable it
  if [[ -f /etc/update-motd.d/51/cloudguest ]]; then
    sudo chmod -x /etc/update-motd.d/51-cloudguest
  fi
  sudo cp "$__motd" /etc/update-motd.d/10-help-text
}