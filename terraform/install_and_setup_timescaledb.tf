locals {
  db_name                   = "events_server_${var.environment}"
  path_to_postgres_data_dir = "/data/postgresql/${var.postgresql_version}/main"
}

resource "terraform_data" "install_and_setup_timescaledb" {
  depends_on = [terraform_data.prepare_ebs_volume_for_writing]

  triggers_replace = {
    volume_attachment  = aws_volume_attachment.timescaledb_volume_attachment.id
    postgresql_version = var.postgresql_version
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.timescaledb.public_ip
    private_key = file("${path.module}/timescaledb.pem")
  }

  provisioner "file" {
    source      = "${path.module}/install_postgres.sh"
    destination = "/home/ubuntu/install_postgres.sh"
  }

  provisioner "file" {
    source      = "${path.module}/install_timescaledb.sh"
    destination = "/home/ubuntu/install_timescaledb.sh"
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "sudo chmod u+x /home/ubuntu/install_postgres.sh",
        "sudo ./install_postgres.sh ${var.postgresql_version} ${var.timescaledb_server_port}  ${local.db_name}",

        "sudo chmod u+x /home/ubuntu/install_timescaledb.sh",
        "sudo ./install_timescaledb.sh ${var.postgresql_version} ${var.timescaledb_version} ${local.db_name}"
      ]
    )
  }
}

resource "terraform_data" "postgres_password" {
  depends_on = [terraform_data.install_and_setup_timescaledb]

  triggers_replace = {
    volume_attachment  = aws_volume_attachment.timescaledb_volume_attachment.id
    postgresql_version = var.postgresql_version
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
        "echo '**************** remote-exec: Setting the postgres user password...'",
        "sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD '${var.timescaledb_server_postgres_password}';\""
      ]
    )
  }
}

output "psql_connect" {
  value       = "psql -h ${aws_instance.timescaledb.public_ip} -U postgres -d ${local.db_name} -p ${var.timescaledb_server_port}"
  description = "Command to connect to the PostgreSQL database using psql."
}
