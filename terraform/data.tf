data "aws_vpc" "timescaledb_vpc" {
  id = var.vpc_id
}

data "aws_subnet" "timescaledb_subnet" {
  id = var.subnet_id
}

data "aws_security_group" "timescaledb_vpc_default_security_group" {
  vpc_id = data.aws_vpc.timescaledb_vpc.id

  filter {
    name   = "group-name"
    values = ["default"]
  }
}
