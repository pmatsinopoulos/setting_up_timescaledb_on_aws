data "aws_subnet" "timescaledb_subnet" {
  id = var.subnet_id
}
