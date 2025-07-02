resource "aws_security_group" "ssh" {
  name        = "${var.project}-${var.environment}-security-group-ssh"
  description = "Allow SSH traffic from anywhere to anywhere"
  vpc_id      = data.aws_vpc.timescaledb_vpc.id
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # egress {
  #   description = "Outgoing to anywhere"
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  tags = {
    "Name" = "${var.project}-${var.environment}-security-group-ssh"
  }
}

resource "aws_security_group" "postgres" {
  name        = "${var.project}-${var.environment}-security-group-postgres"
  description = "Allow postgres traffic from anywhere"
  vpc_id      = data.aws_vpc.timescaledb_vpc.id
  ingress {
    description = "postgres from anywhere"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # egress {
  #   description = "Outgoing to anywhere"
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  tags = {
    "Name" = "${var.project}-${var.environment}-security-group-postgres"
  }
}
