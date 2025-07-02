# This imports the public part of an OpenSSH key.
# The key has been generated using `ssh-keygen` in PEM format.
# Example:
#
# ssh-keygen -m PEM
#
# The key has been generated without a passphrase.
#
resource "aws_key_pair" "timescaledb" {
  key_name   = "${var.project}-${var.environment}-timescaledb"
  public_key = file("${path.module}/timescaledb.pem.pub")

  tags = {
    "Name" = "${var.project}-${var.environment}-timescaledb"
  }
}
