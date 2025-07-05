resource "aws_ebs_volume" "timescaledb_volume" {
  availability_zone = "${var.region}${var.timescaledb_server_availability_zone}"
  size              = 64
  type              = "gp3"
  encrypted         = false
  final_snapshot    = false

  tags = {
    Name = "${var.project}-${var.environment}-timescaledb-volume"
  }
}

resource "aws_volume_attachment" "timescaledb_volume_attachment" {
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.timescaledb_volume.id
  instance_id = aws_instance.timescaledb.id
}
