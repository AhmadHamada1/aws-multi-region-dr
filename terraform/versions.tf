terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
  }
}

# Primary Region: runs the full stack and takes all traffic.
provider "aws" {
  alias  = "primary"
  region = var.primary_region

  default_tags {
    tags = local.common_tags
  }
}

# Secondary Region: warm standby (minimal capacity, scaled up on failover).
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region

  default_tags {
    tags = local.common_tags
  }
}
