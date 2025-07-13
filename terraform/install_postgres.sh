#!/bin/bash

set -e # e: exit if any command has a non-zero exit status
set -x # x: all executed commands are printed to the terminal
set -u # u: all references to variables that have not been previously defined cause an error

NEW_VERSION=$1
PORT=$2
DB_NAME=$3
TIMESCALEDB_VERSION="${4}*"

# Create the PostgreSQL data directory
sudo mkdir -p /data/postgresql

# Update the package list
sudo DEBIAN_FRONTEND=noninteractive apt update -y

# Install postgres common tools
sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-common apt-transport-https net-tools

# Enable the PostgreSQL APT repository
sudo DEBIAN_FRONTEND=noninteractive /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

# Let's now install on top of any existing
CURRENT_CLUSTER=$(sudo pg_lsclusters -h 2>/dev/null | grep "${PORT}" | awk '{print $1"-"$2}' || true)

INSTALL="yes"
OLD_VERSION=""
OLD_NAME="main"
if [ -n "$CURRENT_CLUSTER" ]; then
  echo "Found existing PostgreSQL cluster:"
  echo "$CURRENT_CLUSTER"
  echo

  OLD_VERSION=$(echo $CURRENT_CLUSTER | cut -d'-' -f1)
  OLD_NAME=$(echo $CURRENT_CLUSTER | cut -d'-' -f2)

  # Skip if this is the same version and name we're about to install
  if [ "$OLD_VERSION" = "$NEW_VERSION" ] && [ "$OLD_NAME" = "main" ]; then
      echo "Skipping cluster $OLD_VERSION/$OLD_NAME as it matches the target version and name"
      INSTALL="no"
      continue
  fi

  echo "************************ stopping and disabling $OLD_VERSION/$OLD_NAME ************************"
  sudo systemctl stop postgresql@$OLD_VERSION-$OLD_NAME || true
  sudo systemctl status postgresql@$OLD_VERSION-$OLD_NAME --no-pager || true
  sudo systemctl disable postgresql@$OLD_VERSION-$OLD_NAME || true
  sudo pg_ctlcluster stop $OLD_VERSION $OLD_NAME || true
  sudo pg_lsclusters -h
else
  echo "No existing PostgreSQL clusters found on port ${PORT}. Proceeding with installation."
  echo

  INSTALL="yes"
fi

echo "****************** INSTALL: $INSTALL"
if [ "$INSTALL" = "yes" ]; then
  sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-$NEW_VERSION postgresql-client-$NEW_VERSION postgresql-contrib-$NEW_VERSION
  sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-server-dev-$NEW_VERSION
  # When I install postgresql for the first time, the cluster is already created.
  # But when I install a new version while another already exists, the cluster is not created.
  if sudo pg_lsclusters -h 2>/dev/null | grep -q "^${NEW_VERSION}[[:space:]]\+main[[:space:]]"; then
    echo "Cluster $NEW_VERSION/main already exists"
  else
    echo "Creating cluster $NEW_VERSION/main"
    sudo pg_createcluster $NEW_VERSION main
    sudo pg_ctlcluster start $NEW_VERSION main
    sudo pg_lsclusters -h
  fi
  sudo systemctl start postgresql@${NEW_VERSION}-main
  sudo systemctl enable postgresql@$NEW_VERSION-main
else
  echo "Skipping installation of PostgreSQL ${NEW_VERSION} as it is already installed."
fi

# Show final status

echo "Current PostgreSQL clusters:"
sudo pg_lsclusters -h

sudo systemctl status postgresql@${NEW_VERSION}-main --no-pager

if [ -n "$OLD_VERSION" ]; then
  echo "Stopping and disabling old PostgreSQL cluster $OLD_VERSION/$OLD_NAME"
  sudo pg_ctlcluster stop $OLD_VERSION $OLD_NAME || true
else
  echo "No old PostgreSQL cluster to stop."
fi

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
sudo sed -i "s|port = .*|port = ${PORT}|g" /etc/postgresql/${NEW_VERSION}/main/postgresql.conf

# Allow remote connections
sudo sed -i "s|#listen_addresses = 'localhost'|listen_addresses = '*'|g" /etc/postgresql/${NEW_VERSION}/main/postgresql.conf
sudo sed -i "s|host    all             all             127.0.0.1/32            scram-sha-256|host    all             all             0.0.0.0/0            scram-sha-256|g" /etc/postgresql/${NEW_VERSION}/main/pg_hba.conf

# upgrade from previous version if needed
LAST_CLUSTER=$(echo "$CURRENT_CLUSTER" | tail -n 1)
if [ -n "$LAST_CLUSTER" ]; then
    OLD_VERSION=$(echo $LAST_CLUSTER | cut -d'-' -f1)
    OLD_NAME=$(echo $LAST_CLUSTER | cut -d'-' -f2)
    if [ "$OLD_VERSION" = "$NEW_VERSION" ] && [ "$OLD_NAME" = "main" ]; then
      echo "...no need to upgrade data, we are on the same cluster version and name"
    else
      echo "We need to upgrade the data of the last cluster ${OLD_VERSION}-${OLD_NAME}"
      # We will need to install timescale db for the new version, otherwise the pg_upgrade will fail
      # ---------------------------------------------------------------------------------------------
      sudo apt install timescaledb-2-postgresql-${NEW_VERSION}="${TIMESCALEDB_VERSION}" timescaledb-2-loader-postgresql-${NEW_VERSION}="${TIMESCALEDB_VERSION}" timescaledb-toolkit-postgresql-${NEW_VERSION} -y

      sudo sed -i "s|#shared_preload_libraries = ''|shared_preload_libraries = 'timescaledb'|g" /data/postgresql/${NEW_VERSION}/main/postgresql.conf

      # Tune TimescaleDB
      sudo timescaledb-tune --yes
      # --------------- end of installing timescale db for the new version -----------------------------

      (cd /tmp && sudo -u postgres /usr/lib/postgresql/${NEW_VERSION}/bin/pg_upgrade \
        --old-datadir=/data/postgresql/$OLD_VERSION/$OLD_NAME \
        --new-datadir=/data/postgresql/$NEW_VERSION/main \
        --old-bindir=/usr/lib/postgresql/$OLD_VERSION/bin \
        --new-bindir=/usr/lib/postgresql/$NEW_VERSION/bin)
    fi
fi

# Restart PostgreSQL to apply changes
sudo systemctl restart postgresql@${NEW_VERSION}-main

# Wait for PostgreSQL to start
sleep 10

# Create the database
sudo -u postgres psql -c "create database ${DB_NAME};" || echo "Database ${DB_NAME} already exists, skipping creation."
