# Without +alias+ this is the default +aws+ provider
#
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      project     = var.project
      terraform   = "1"
      environment = var.environment
      tf_repo     = var.repository_url
      tf_folder   = "terraform/${var.environment}"
    }
  }
}
