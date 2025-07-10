#!/bin/bash

set -e # e: exit if any command has a non-zero exit status
set -x # x: all executed commands are printed to the terminal
set -u # u: all references to variables that have not been previously defined cause an error

NEW_VERSION=$1
PORT=$2
DB_NAME=$3

# Create the PostgreSQL data directory
sudo mkdir -p /data/postgresql

# Update the package list
sudo DEBIAN_FRONTEND=noninteractive apt update -y

# Install postgres common tools
sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-common apt-transport-https net-tools

# Enable the PostgreSQL APT repository
sudo DEBIAN_FRONTEND=noninteractive /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

# Let's now install on top of any existing
CURRENT_CLUSTERS=$(sudo pg_lsclusters -h 2>/dev/null | grep "${PORT}" | awk '{print $1"-"$2}' || true)

INSTALL="yes"
if [ -n "$CURRENT_CLUSTERS" ]; then
  echo "Found existing PostgreSQL clusters:"
  echo "$CURRENT_CLUSTERS"
  echo

  # Stop and remove existing clusters
  for cluster in $CURRENT_CLUSTERS; do
      version=$(echo $cluster | cut -d'-' -f1)
      name=$(echo $cluster | cut -d'-' -f2)

      # Skip if this is the same version and name we're about to install
      if [ "$version" = "$NEW_VERSION" ] && [ "$name" = "main" ]; then
          echo "Skipping cluster $version/$name as it matches the target version and name"
          INSTALL="no"
          continue
      fi

      echo "************************ Removing $version/$name ************************"
      sudo systemctl stop postgresql@$version-$name || true
      sudo systemctl disable postgresql@$version-$name || true
      sudo mv /etc/postgresql/$version /etc/postgresql-$version.bak || true
      sudo DEBIAN_FRONTEND=noninteractive apt remove --purge postgresql-$version postgresql-client-$version postgresql-contrib-$version -y || true
      sudo rm -rf /var/lib/postgresql/
      sudo rm -rf /etc/postgresql/
  done
else
  echo "No existing PostgreSQL clusters found on port ${PORT}. Proceeding with installation."
  echo

  INSTALL="yes"
fi

if [ "$INSTALL" = "yes" ]; then
  sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-$NEW_VERSION postgresql-client-$NEW_VERSION postgresql-contrib-$NEW_VERSION
  sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-server-dev-$NEW_VERSION
  sudo systemctl enable postgresql@$NEW_VERSION-main
else
  echo "Skipping installation of PostgreSQL ${NEW_VERSION} as it is already installed."
fi

# Show final status

echo "Current PostgreSQL clusters:"
sudo pg_lsclusters -h

sudo systemctl status postgresql@${NEW_VERSION}-main --no-pager

# Stop postgres from running
sudo systemctl stop postgresql@${NEW_VERSION}-main

# Change where PostgreSQL stores its data
ORIGINAL_DATA_DIR="/var/lib/postgresql/${NEW_VERSION}/main"

if [ -d "${ORIGINAL_DATA_DIR}" ];then
  if [ -d "/var/lib/postgresql/${NEW_VERSION}/main.bak" ]; then
    rm -f -R /var/lib/postgresql/${NEW_VERSION}/main.bak
  fi
  sudo mv ${ORIGINAL_DATA_DIR} /var/lib/postgresql/${NEW_VERSION}/main.bak
fi

NEW_PATH_TO_POSTGRES_DATA_DIR="/data/postgresql/${NEW_VERSION}/main"

sudo mkdir -p ${NEW_PATH_TO_POSTGRES_DATA_DIR}
sudo chown -R postgres:postgres /data/postgresql
if [ -n "$(sudo ls -A ${NEW_PATH_TO_POSTGRES_DATA_DIR} 2>/dev/null)" ]; then
  echo "The new PostgreSQL data directory is not empty. We will not initialize it."
else
  echo "Initializing new PostgreSQL data directory at ${NEW_PATH_TO_POSTGRES_DATA_DIR}"
  sudo -u postgres /usr/lib/postgresql/${NEW_VERSION}/bin/initdb -D ${NEW_PATH_TO_POSTGRES_DATA_DIR}
fi
sudo sed -i "s|data_directory = '${ORIGINAL_DATA_DIR}'|data_directory = '${NEW_PATH_TO_POSTGRES_DATA_DIR}'|g" /etc/postgresql/${NEW_VERSION}/main/postgresql.conf

# Set the port to whatever we specify as port in the terraform variables
sudo sed -i "s|port = 5432|port = ${PORT}|g" /etc/postgresql/${NEW_VERSION}/main/postgresql.conf

# Allow remote connections
sudo sed -i "s|#listen_addresses = 'localhost'|listen_addresses = '*'|g" /etc/postgresql/${NEW_VERSION}/main/postgresql.conf
sudo sed -i "s|host    all             all             127.0.0.1/32            scram-sha-256|host    all             all             0.0.0.0/0            scram-sha-256|g" /etc/postgresql/${NEW_VERSION}/main/pg_hba.conf

# upgrade from previous version if needed
LAST_CLUSTER=$(echo "$CURRENT_CLUSTERS" | tail -n 1)
if [ -n "$LAST_CLUSTER" ]; then
    version=$(echo $LAST_CLUSTER | cut -d'-' -f1)
    name=$(echo $LAST_CLUSTER | cut -d'-' -f2)
    if [ "$version" = "$NEW_VERSION" ] && [ "$name" = "main" ]; then
      echo "...no need to upgrade data, we are on the same cluster version and name"
    else
      echo "We need to upgrade the data of the last cluster ${version}-${name}"
      sudo -u postgres /usr/lib/postgresql/${NEW_VERSION}/bin/pg_upgrade \
        --old-datadir=/data/postgresql/$version/$name \
        --new-datadir=/data/postgresql/$NEW_VERSION/main \
        --old-bindir=/usr/lib/postgresql/$version/bin \
        --new-bindir=/usr/lib/postgresql/$NEW_VERSION/bin
    fi
fi

# Restart PostgreSQL to apply changes
sudo systemctl start postgresql@${NEW_VERSION}-main

# Wait for PostgreSQL to start
sleep 10

# Create the database
sudo -u postgres psql -c "create database ${DB_NAME};" || echo "Database ${DB_NAME} already exists, skipping creation."
