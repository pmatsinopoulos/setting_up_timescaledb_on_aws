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

if [ -n "$CURRENT_CLUSTERS" ]; then
    echo "Found existing PostgreSQL clusters:"
    echo "$CURRENT_CLUSTERS"
    echo

    # Stop and remove existing clusters on port 5432
    for cluster in $CURRENT_CLUSTERS; do
        version=$(echo $cluster | cut -d'-' -f1)
        name=$(echo $cluster | cut -d'-' -f2)

        # Skip if this is the same version and name we're about to install
        if [ "$version" = "$NEW_VERSION" ] && [ "$name" = "main" ]; then
            echo "Skipping cluster $version/$name as it matches the target version and name"
            continue
        fi
        echo "Stopping cluster: $version/$name"
        sudo pg_ctlcluster $version $name stop || true

        echo "Dropping cluster: $version/$name"
        sudo pg_dropcluster $version $name || true
    done
    echo
else
  echo "No existing PostgreSQL clusters found on port ${PORT}. Proceeding with installation."
  echo

  sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-$NEW_VERSION

  sudo systemctl enable postgresql@$NEW_VERSION-main
fi

# Show final status

echo "Current PostgreSQL clusters:"
sudo pg_lsclusters -h

sudo systemctl status postgresql@${NEW_VERSION}-main --no-pager

# Stop postgres from running
sudo systemctl stop postgresql

# Change where PostgreSQL stores its data
ORIGINAL_DATA_DIR="/var/lib/postgresql/${NEW_VERSION}/main"

if [ -d "${ORIGINAL_DATA_DIR}" ];then
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

# Restart PostgreSQL to apply changes
sudo systemctl start postgresql@${NEW_VERSION}-main

# Wait for PostgreSQL to start
sleep 10

# Create the database
sudo -u postgres psql -c "create database ${DB_NAME};" || echo "Database ${DB_NAME} already exists, skipping creation."
