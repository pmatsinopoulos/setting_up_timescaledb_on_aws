data "aws_ami" "timescaledb" {
  most_recent = true

  filter {
    name   = "block-device-mapping.delete-on-termination"
    values = ["true"]
  }

  filter {
    name   = "is-public"
    values = ["true"]
  }


  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "timescaledb" {
  ami               = data.aws_ami.timescaledb.id
  instance_type     = var.timescaledb_server_instance_type
  availability_zone = "${var.region}${var.timescaledb_server_availability_zone}"
  subnet_id         = var.subnet_id
  vpc_security_group_ids = [
    data.aws_security_group.timescaledb_vpc_default_security_group.id,
    aws_security_group.ssh.id,
    aws_security_group.postgres.id,
  ]
  key_name                    = aws_key_pair.timescaledb.key_name
  associate_public_ip_address = true

  tags = {
    "Name" = "${var.project}-${var.environment}-timescaledb"
  }
}

output "ec2_timescaledb_public_ip" {
  value       = aws_instance.timescaledb.public_ip
  description = "The public IP address of the EC2 Timescale DB Machine"
}

output "ssh_connect" {
  value       = "ssh -i ${path.module}/timescaledb.pem -o IdentitiesOnly=yes ubuntu@${aws_instance.timescaledb.public_ip}"
  description = "SSH command to connect to the Timescale DB EC2 instance"
}
