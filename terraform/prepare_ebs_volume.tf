resource "terraform_data" "prepare_ebs_volume_for_writing" {
  depends_on = [aws_volume_attachment.timescaledb_volume_attachment]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.timescaledb.public_ip
    private_key = file("${path.module}/timescaledb.pem")
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "sudo file -s /dev/nvme1n1 | grep -q '/dev/nvme1n1: data$' && sudo mkfs -t xfs /dev/nvme1n1",
        "sudo mkdir /data",
        "sudo mount /dev/nvme1n1 /data",
        "sudo cp /etc/fstab /etc/fstab.bak",
        "echo \"UUID=$(sudo blkid -s UUID -o value /dev/nvme1n1) /data xfs defaults,nofail 0 2\" | sudo tee -a /etc/fstab",
        # "sudo mkdir -p /data/postgresql",
        # "sudo DEBIAN_FRONTEND=noninteractive apt update -y",
        # "sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-common apt-transport-https net-tools",
        # "sudo DEBIAN_FRONTEND=noninteractive /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y",
        # "sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-server-dev-${local.postgresql_version}",
        # "echo \"deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main\" | sudo tee /etc/apt/sources.list.d/timescaledb.list",
        # "wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg",
        # "sudo DEBIAN_FRONTEND=noninteractive apt update -y",
        # "sudo apt install timescaledb-2-postgresql-${local.postgresql_version}='${local.timescale_db_version}*' timescaledb-2-loader-postgresql-${local.postgresql_version}='${local.timescale_db_version}*' postgresql-client-${local.postgresql_version} -y",
        # "sudo apt install timescaledb-toolkit-postgresql-${local.postgresql_version} -y",
        # "sudo systemctl stop postgresql",
        # "sudo mv /var/lib/postgresql/${local.postgresql_version}/main /var/lib/postgresql/${local.postgresql_version}/main.bak",
        # "sudo mkdir -p /data/postgresql/${local.postgresql_version}/main",
        # "sudo chown -R postgres:postgres /data/postgresql",
        # "sudo -u postgres /usr/lib/postgresql/${local.postgresql_version}/bin/initdb -D /data/postgresql/${local.postgresql_version}/main",
        # "sudo sed -i \"s|data_directory = '/var/lib/postgresql/${local.postgresql_version}/main'|data_directory = '/data/postgresql/${local.postgresql_version}/main'|g\" /etc/postgresql/${local.postgresql_version}/main/postgresql.conf",
        # "sudo sed -i \"s|port = 5432|port = ${var.timescale_db_server.port}|g\" /etc/postgresql/${local.postgresql_version}/main/postgresql.conf",
        # "sudo sed -i \"s|#listen_addresses = 'localhost'|listen_addresses = '*'|g\" /etc/postgresql/${local.postgresql_version}/main/postgresql.conf",
        # "sudo sed -i \"s|host    all             all             127.0.0.1/32            scram-sha-256|host    all             all             0.0.0.0/0            scram-sha-256|g\" /etc/postgresql/${local.postgresql_version}/main/pg_hba.conf",
        # "sudo timescaledb-tune --yes",
        # "sudo systemctl restart postgresql",
        # "sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD '${var.timescale_db_server_credentials.postgres_password}';\"",
        # "sudo -u postgres psql -c \"create database ${local.db_name};\"",
        # "sudo -u postgres psql -d ${local.db_name} -c \"CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;\"",
        # "sudo -u postgres psql -d ${local.db_name} -c \"CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit CASCADE;\"",
      ]
    )
  }
}
