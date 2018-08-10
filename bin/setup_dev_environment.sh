#!/bin/bash

# https://github.com/deoren/redmine-testing

# Purpose: Help setup new Ubuntu 16.04 VM for testing Redmine trunk


# Do not allow use of unitilized variables
set -u

# errtrace
#         Same as -E.
#
# -E      If set, any trap on ERR is inherited by shell functions,
#         command substitutions, and commands executed in a sub‐
#         shell environment.  The ERR trap is normally not inher‐
#         ited in such cases.
set -o errtrace

# Exit if any statement returns a non-true value
# http://mywiki.wooledge.org/BashFAQ/105
# set -e

# Exit if ANY command in a pipeline fails instead of allowing the exit code
# of later commands in the pipeline to determine overall success
set -o pipefail

trap 'echo "Error occurred on line $LINENO."' ERR


if [[ "$UID" -eq 0 ]]; then
  echo "Run this script without sudo or as root, sudo will be called as needed."
  exit 1
fi

REDMINE_SVN_URL="http://svn.redmine.org/redmine/trunk"
BASE_REDMINE_INSTALL_DIR="/opt/redmine"
REDMINE_DEST_DIR="${BASE_REDMINE_INSTALL_DIR}/trunk"

THIS_DEV_ENV_GIT_REPO_URL="https://github.com/deoren/redmine-testing"
THIS_DEV_ENV_GIT_REPO_BASENAME="$(basename ${THIS_DEV_ENV_GIT_REPO_URL})"


echo "* Performing initial refresh of package lists ..."
sudo apt-get update ||
    { echo "Another apt operation is probably in progress. Try again."; exit 1; }

echo "* Installing git in order to fetch repos ..."
sudo apt-get install -y git ||
    { echo "Failed to install git packages. Aborting!"; exit 1; }


cd /tmp

echo "* Removing old clone of ${THIS_DEV_ENV_GIT_REPO_URL} ..."
sudo rm -rf ${THIS_DEV_ENV_GIT_REPO_BASENAME}


echo "* Cloning ${THIS_DEV_ENV_GIT_REPO_URL} ..."
git clone ${THIS_DEV_ENV_GIT_REPO_URL} ||
    { echo "Failed to clone ${THIS_DEV_ENV_GIT_REPO_URL}. Aborting!"; exit 1; }


######################################################
# Setup upstream apt repos
######################################################

echo "* Deploying apt preference files ..."

# Override conflict between nginx and Phusion Passenger repos by boosting
# precedence of the upstream nginx repo packages
sudo cp -vf /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/etc/apt/preferences.d/nginx /etc/apt/preferences.d/ ||
    { echo "Failed to deploy apt preference file. Aborting!"; exit 1; }

echo "* Deploying apt repo config files ..."

# Repo conf files
for apt_repo_conf_file in phusion-passenger.list mariadb-server.list nginx.list
do
    sudo cp -vf /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/etc/apt/sources.list.d/${apt_repo_conf_file} /etc/apt/sources.list.d/ ||
        { echo "[!] Failed to deploy ${apt_repo_conf_file} ... aborting"; exit 1; }
done

######################################################
# Install package signing keys
######################################################

echo "* Installing apt repo package signing keys ..."

# MariaDB
if [[ ! -f /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/keys/mariadb_signing.key ]]; then
    sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8 ||
        { echo "[!] Failed to retrieve MariaDB signing key ... aborting"; exit 1; }
else
    sudo apt-key add /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/keys/mariadb_signing.key ||
        { echo "[!] Failed to install local repo copy of MariaDB signing key ... aborting"; exit 1; }
fi

# Nginx
if [[ ! -f /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/keys/nginx_signing.key ]]; then
    wget https://nginx.org/keys/nginx_signing.key -O - | sudo apt-key add - ||
        { echo "Failed to retrieve nginx package signing key. Aborting!"; exit 1; }
else
    sudo apt-key add /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/keys/nginx_signing.key ||
        { echo "[!] Failed to install local repo copy of nginx signing key ... aborting"; exit 1; }
fi

# Phusion Passenger
if [[ ! -f /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/keys/phusion_signing.key ]]; then
    sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 561F9B9CAC40B2F7 ||
        { echo "[!] Failed to retrieve Phusion Passenger signing key ... aborting"; exit 1; }
else
    sudo apt-key add /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/keys/phusion_signing.key ||
        { echo "[!] Failed to install local repo copy of Phusion signing key ... aborting"; exit 1; }

fi

######################################################
# Install packages
######################################################


echo "* Refreshing package lists ..."
sudo apt-get update ||
    { echo "Another apt operation is probably in progress. Try again."; exit 1; }

echo "* Installing primary packages ..."
sudo apt-get install -y \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    nginx \
    ruby \
    ruby-dev \
    ruby-bundler \
    libsqlite3-dev \
    imagemagick \
    libmagickwand-dev \
    passenger \
    subversion \
    sqlite3 \
    python3-pip \
    sqlitebrowser \
    ||
        { echo "Failed to install required packages. Try again."; exit 1; }

# Install MariaDB without prompts, relying on default behavior of no password
echo "* Installing MariaDB ..."
sudo DEBIAN_FRONTEND=noninteractive apt-get -q -y install mariadb-server libmariadbclient-dev ||
    { echo "Failed to install MariaDB packages. Aborting!"; exit 1; }



######################################################
# Setup database
######################################################

# Use SQL file to setup database, create account and grant permissions to db
echo "* Setting up database, user, access ..."
mysql -u root < /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/sql/setup_redmine_database.sql ||
    { echo "Failed to setup 'redmine' database. Aborting!"; exit 1; }

cd ${THIS_DEV_ENV_GIT_REPO_BASENAME}

# Abort if existing installation found
if [[ -d ${REDMINE_DEST_DIR} ]]
then
    echo "Existing Redmine installation found: ${REDMINE_DEST_DIR}"
    echo "Aborting installation!"
    exit 1
else
    sudo mkdir -vp ${BASE_REDMINE_INSTALL_DIR}
fi

SERVICE_ACCOUNT="redmine-trunk"

echo "* Checking out Redmine from SVN trunk ... "
sudo svn co ${REDMINE_SVN_URL} ${REDMINE_DEST_DIR} ||
    { echo "Failed to checkout ${REDMINE_SVN_URL}. Aborting!"; exit 1; }

cd ${REDMINE_DEST_DIR}
sudo mkdir -vp \
    ${REDMINE_DEST_DIR}/tmp \
    ${REDMINE_DEST_DIR}/tmp/pdf \
    ${REDMINE_DEST_DIR}/public/plugin_assets

echo "* Deploying Redmine configuration files for ${SERVICE_ACCOUNT} ... "
sudo cp -fv \
    /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/${REDMINE_DEST_DIR}/config/database.yml \
    ${REDMINE_DEST_DIR}/config/

sudo cp -fv \
    /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/${REDMINE_DEST_DIR}/Passengerfile.json \
        ${REDMINE_DEST_DIR}/

# Install dependencies locally instead of system-wide
echo "* Installing required gems via bundler ... "
sudo bundle install --without development test  --path vendor/bundle ||
    { echo "Failed to install required gems via bundler. Aborting!"; exit 1; }

echo "* Setting up database for use (NOTE: this takes a while) ..."
sudo bundle exec rake generate_secret_token ||
    { echo "Failed to generate secret token. Aborting!"; exit 1; }

sudo RAILS_ENV=development bundle exec rake db:migrate ||
    { echo "Failed to run database migrations. Aborting!"; exit 1; }

sudo RAILS_ENV=development REDMINE_LANG=en bundle exec rake redmine:load_default_data ||
    { echo "Failed to load default data into database. Aborting!"; exit 1; }

echo "* Creating service account: ${SERVICE_ACCOUNT} ..."
sudo useradd \
    --system \
    --user-group \
    --create-home \
    --shell /bin/bash \
    ${SERVICE_ACCOUNT} ||
        { echo "Failed to create service account ${SERVICE_ACCOUNT}. Aborting!"; exit 1; }

echo "* Adjusting permissions to grant ${SERVICE_ACCOUNT} service account required access ..."
sudo chown -Rv ${SERVICE_ACCOUNT}: \
    ${REDMINE_DEST_DIR}/tmp \
    ${REDMINE_DEST_DIR}/log \
    ${REDMINE_DEST_DIR}/files \
    ${REDMINE_DEST_DIR}/public/plugin_assets

sudo chmod -Rv 755 \
    ${REDMINE_DEST_DIR}/tmp \
    ${REDMINE_DEST_DIR}/log \
    ${REDMINE_DEST_DIR}/files \
    ${REDMINE_DEST_DIR}/public/plugin_assets


echo "* Add execute bit to Redmine HTTP API submission script ..."
sudo chmod -v +x ${REDMINE_DEST_DIR}/extra/mail_handler/rdm-mailhandler.rb ||
    { echo "Failed to add execute bit to Redmine HTTP API submission script. Aborting!"; exit 1; }

echo "* Adjusting permissions on database config file ..."
sudo chown -v root:${SERVICE_ACCOUNT} \
    ${REDMINE_DEST_DIR}/config/database.yml

sudo chmod -v 0640 \
    ${REDMINE_DEST_DIR}/config/database.yml

# Allow application service account to write to database directory
# Note: Required for SQLite3, completely optional for MariaDB/redmine/trunk
sudo chown -vR root:${SERVICE_ACCOUNT} \
    ${REDMINE_DEST_DIR}/db ||
    { echo "Failed to set ownership on db directory. Aborting!"; exit 1; }

sudo chmod -vR u+rwX,g+rwX,o= ${REDMINE_DEST_DIR}/db ||
    { echo "Failed to set permissions on db directory. Aborting!"; exit 1; }

if [ $? -eq 0 ]; then

    echo "* Deploying Phusion Passenger:Redmine (mysql) systemd unit ..."
    sudo cp -fv /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/etc/systemd/system/passenger-redmine-trunk.service /etc/systemd/system/ ||
        { echo "Failed to deploy Phusion Passenger:Redmine (mysql) systemd unit. Aborting!"; exit 1; }

    # Force systemd to see the new unit file
    sudo systemctl daemon-reload
fi

if [ $? -eq 0 ]; then

    echo "* Setting Phusion Passenger:Redmine (mysql) systemd unit to start at boot ..."
    sudo systemctl enable passenger-redmine-trunk.service ||
        { echo "Failed to enable Phusion Passenger:Redmine (mysql) systemd unit. Aborting!"; exit 1; }

    echo "* Launching Phusion Passenger:Redmine (mysql) systemd unit ..."
    sudo systemctl start passenger-redmine-trunk.service ||
        { echo "Failed to start Phusion Passenger:Redmine (mysql) systemd unit. Aborting!"; exit 1; }

fi

echo "* Copying nginx conf files ..."
sudo mkdir -vp /etc/nginx /etc/nginx/sites-available
sudo cp -vf /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/etc/nginx/*.conf /etc/nginx/
sudo cp -vf /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/etc/nginx/sites-available/*.conf /etc/nginx/sites-available/

echo "* Enabling/Restarting nginx ..."
sudo systemctl enable nginx ||
    { echo "Failed to enable nginx systemd unit. Aborting!"; exit 1; }

sudo systemctl restart nginx ||
    { echo "Failed to restart nginx systemd unit. Aborting!"; exit 1; }

