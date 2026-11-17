locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {
  provider = aws.primary
}

# ---------------- Database credentials ----------------
# Generated once, stored in Secrets Manager in the primary Region and
# replicated to the secondary Region so the standby can read it during an outage.

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  provider                = aws.primary
  name                    = "${local.name}/aurora-master"
  recovery_window_in_days = 0

  replica {
    region = var.secondary_region
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  provider  = aws.primary
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    dbname   = var.db_name
  })
}

# ---------------- The same stack in both Regions ----------------
# One module, two providers: identical infrastructure in both Regions
# (the Terraform equivalent of a CloudFormation StackSet).

module "primary" {
  source    = "./modules/region"
  providers = { aws = aws.primary }

  name                = "${local.name}-pri"
  role                = "primary"
  vpc_cidr            = var.primary_vpc_cidr
  instance_type       = var.instance_type
  capacity            = var.primary_capacity
  dynamodb_table_name = aws_dynamodb_table.sessions.name
  db_endpoint         = aws_rds_cluster.primary.endpoint
  db_secret_arn       = aws_secretsmanager_secret.db.arn
}

module "secondary" {
  source    = "./modules/region"
  providers = { aws = aws.secondary }

  name                = "${local.name}-sec"
  role                = "secondary"
  vpc_cidr            = var.secondary_vpc_cidr
  instance_type       = var.instance_type
  capacity            = var.standby_capacity
  dynamodb_table_name = aws_dynamodb_table.sessions.name
  db_endpoint         = aws_rds_cluster.secondary.reader_endpoint
  db_secret_arn       = replace(aws_secretsmanager_secret.db.arn, ":${var.primary_region}:", ":${var.secondary_region}:")

  depends_on = [aws_dynamodb_table.sessions]
}
