variable "region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "The name of the project."
  type        = string
  default     = "setting_up_timescaledb_on_aws"
}

variable "environment" {
  description = "The environment for the deployment (e.g., development, staging, production)."
  type        = string
  default     = "development"
}

variable "repository_url" {
  description = "The GitHub repository URL for the project."
  type        = string
  default     = "https://github.com/pmatsinopoulos/setting_up_timescaledb_on_aws"
}

variable "vpc_id" {
  description = "The ID of the VPC where the EC2 instance will be launched in."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet where the EC2 instance will be launched in."
  type        = string
}

variable "timescaledb_server_availability_zone" {
  description = "The availability zone for the TimescaleDB server."
  type        = string
  default     = "a"
}

variable "timescaledb_server_instance_type" {
  description = "The instance type for the TimescaleDB server."
  type        = string
  default     = "t3.xlarge"
}

variable "postgresql_version" {
  description = "The PostgreSQL version to install on the TimescaleDB server."
  type        = string
  default     = "17"
}

variable "timescaledb_version" {
  description = "The TimescaleDB version to install on the TimescaleDB server."
  type        = string
  default     = "2.19.3"
}

variable "timescaledb_server_port" {
  description = "Port for the TimescaleDB server."
  type        = number
  default     = 5432
}

variable "timescaledb_server_postgres_password" {
  description = "The password for the PostgreSQL user on the TimescaleDB server."
  type        = string
  sensitive   = true
}
