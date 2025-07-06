locals {
  db_name                   = "events_server_${var.environment}"
  path_to_postgres_data_dir = "/data/postgresql/${var.postgresql_version}/main"
}

resource "terraform_data" "install_and_setup_timescaledb" {
  depends_on = [terraform_data.prepare_ebs_volume_for_writing]

  triggers_replace = {
    volume_attachment = aws_volume_attachment.timescaledb_volume_attachment.id
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.timescaledb.public_ip
    private_key = file("${path.module}/timescaledb.pem")
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        // Create the PostgreSQL data directory
        "sudo mkdir -p /data/postgresql",

        // Update the package list
        "sudo DEBIAN_FRONTEND=noninteractive apt update -y",

        // Install postgres
        "sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-common apt-transport-https net-tools",
        "sudo DEBIAN_FRONTEND=noninteractive /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y",
        "sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-server-dev-${var.postgresql_version}",

        // Set TimescaleDB repository at system repositories so that we can install TimescaleDB
        "echo \"deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main\" | sudo tee /etc/apt/sources.list.d/timescaledb.list",
        "wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/timescaledb.gpg",
        "sudo DEBIAN_FRONTEND=noninteractive apt update -y",

        // Install TimescaleDB
        "sudo apt install timescaledb-2-postgresql-${var.postgresql_version}='${var.timescaledb_version}*' timescaledb-2-loader-postgresql-${var.postgresql_version}='${var.timescaledb_version}*' postgresql-client-${var.postgresql_version} -y",

        // Install TimescaleDB Toolkit
        "sudo apt install timescaledb-toolkit-postgresql-${var.postgresql_version} -y",

        // Stop postgres from running
        "sudo systemctl stop postgresql",

        // Change where PostgreSQL stores its data
        "[ -d \"/var/lib/postgresql/${var.postgresql_version}/main\"] && sudo mv /var/lib/postgresql/${var.postgresql_version}/main /var/lib/postgresql/${var.postgresql_version}/main.bak",
        "sudo mkdir -p ${local.path_to_postgres_data_dir}",
        "sudo chown -R postgres:postgres /data/postgresql",
        "[ -d \"${local.path_to_postgres_data_dir}\" ] && [ -n \"$(sudo ls -A ${local.path_to_postgres_data_dir} 2>/dev/null)\" ] || sudo -u postgres /usr/lib/postgresql/${var.postgresql_version}/bin/initdb -D ${local.path_to_postgres_data_dir}",
        "sudo sed -i \"s|data_directory = '/var/lib/postgresql/${var.postgresql_version}/main'|data_directory = '${local.path_to_postgres_data_dir}'|g\" /etc/postgresql/${var.postgresql_version}/main/postgresql.conf",

        // Set the port to whatever we specify as port in the terraform variables
        "sudo sed -i \"s|port = 5432|port = ${var.timescaledb_server_port}|g\" /etc/postgresql/${var.postgresql_version}/main/postgresql.conf",

        // Allow remote connections
        "sudo sed -i \"s|#listen_addresses = 'localhost'|listen_addresses = '*'|g\" /etc/postgresql/${var.postgresql_version}/main/postgresql.conf",
        "sudo sed -i \"s|host    all             all             127.0.0.1/32            scram-sha-256|host    all             all             0.0.0.0/0            scram-sha-256|g\" /etc/postgresql/${var.postgresql_version}/main/pg_hba.conf",

        // Tune TimescaleDB
        "sudo timescaledb-tune --yes",

        // Restart PostgreSQL to apply changes
        "sudo systemctl restart postgresql",

        "sleep 10", // Wait for PostgreSQL to start

        // Create the database and set the password for the postgres user
        "sudo -u postgres psql -c \"create database ${local.db_name};\" || echo \"Database ${local.db_name} already exists, skipping creation.\"",

        // Create the extensions for TimescaleDB and TimescaleDB Toolkit
        "sudo -u postgres psql -d ${local.db_name} -c \"CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;\"",
        "sudo -u postgres psql -d ${local.db_name} -c \"CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit CASCADE;\"",
      ]
    )
  }
}

resource "terraform_data" "postgres_password" {
  depends_on = [terraform_data.install_and_setup_timescaledb]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.timescaledb.public_ip
    private_key = file("${path.module}/timescaledb.pem")
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD '${var.timescaledb_server_postgres_password}';\""
      ]
    )
  }
}

output "psql_connect" {
  value       = "psql -h ${aws_instance.timescaledb.public_ip} -U postgres -d ${local.db_name} -p ${var.timescaledb_server_port}"
  description = "Command to connect to the PostgreSQL database using psql."
}
