variable "region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "eu-central-1"
}

variable "subnet_id" {
  description = "The ID of the subnet where the EC2 instance will be launched in."
  type        = string
}
