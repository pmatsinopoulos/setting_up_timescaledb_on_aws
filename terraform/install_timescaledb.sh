#!/bin/bash

set -e # e: exit if any command has a non-zero exit status
set -x # x: all executed commands are printed to the terminal
set -u # u: all references to variables that have not been previously defined cause an error

POSTGRESQL_VERSION=$1
TIMESCALEDB_VERSION="${2}*"
DB_NAME=$3
# Set TimescaleDB repository at system repositories so that we can install TimescaleDB
echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/timescaledb.gpg
sudo DEBIAN_FRONTEND=noninteractive apt update -y

sudo systemctl stop postgresql@${POSTGRESQL_VERSION}-main || true

# Install TimescaleDB and TimescaleDB Toolkit all TimescaleDB postgres related packages
sudo apt install timescaledb-2-postgresql-${POSTGRESQL_VERSION}="${TIMESCALEDB_VERSION}" timescaledb-2-loader-postgresql-${POSTGRESQL_VERSION}="${TIMESCALEDB_VERSION}" timescaledb-toolkit-postgresql-${POSTGRESQL_VERSION} -y

sudo sed -i "s|#shared_preload_libraries = ''|shared_preload_libraries = 'timescaledb'|g" /data/postgresql/${POSTGRESQL_VERSION}/main/postgresql.conf

# Tune TimescaleDB
sudo timescaledb-tune --yes

sudo systemctl restart postgresql@${POSTGRESQL_VERSION}-main

# Create the extensions for TimescaleDB and TimescaleDB Toolkit
sudo -u postgres psql -d ${DB_NAME} -c "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"
sudo -u postgres psql -d ${DB_NAME} -c "CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit CASCADE;"
