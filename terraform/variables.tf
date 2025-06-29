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

variable "subnet_id" {
  description = "The ID of the subnet where the EC2 instance will be launched in."
  type        = string
}
