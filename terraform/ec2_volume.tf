resource "aws_ebs_volume" "timescaledb_volume" {
  availability_zone = "${var.region}${var.timescaledb_server_availability_zone}"
  size              = 64
  type              = "gp3"
  encrypted         = false
  final_snapshot    = true

  tags = {
    Name = "${var.project}-${var.environment}-timescaledb-volume"
  }
}
