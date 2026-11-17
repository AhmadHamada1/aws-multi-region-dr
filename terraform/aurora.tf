# Aurora Global Database: one writer cluster in the primary Region and a
# read-only cluster in the secondary Region. Storage-level replication is
# typically under 1 second (RPO < 1s); promoting the secondary takes ~1 minute.

resource "aws_kms_key" "aurora_secondary" {
  provider                = aws.secondary
  description             = "${local.name} Aurora encryption key (secondary Region)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_rds_global_cluster" "this" {
  provider                  = aws.primary
  global_cluster_identifier = "${local.name}-global"
  engine                    = "aurora-mysql"
  engine_version            = var.aurora_engine_version
  database_name             = var.db_name
  storage_encrypted         = true
  deletion_protection       = false
}

resource "aws_rds_cluster" "primary" {
  provider                  = aws.primary
  cluster_identifier        = "${local.name}-pri"
  global_cluster_identifier = aws_rds_global_cluster.this.id
  engine                    = aws_rds_global_cluster.this.engine
  engine_version            = aws_rds_global_cluster.this.engine_version
  database_name             = var.db_name
  master_username           = var.db_username
  master_password           = random_password.db.result
  db_subnet_group_name      = module.primary.db_subnet_group_name
  vpc_security_group_ids    = [module.primary.db_security_group_id]
  storage_encrypted         = true
  backup_retention_period   = 7
  skip_final_snapshot       = true

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_acu
    max_capacity = var.aurora_max_acu
  }

  tags = { Backup = "true" }

  # After a failover/switchover the roles move; don't let Terraform undo it.
  lifecycle {
    ignore_changes = [global_cluster_identifier, replication_source_identifier]
  }
}

resource "aws_rds_cluster_instance" "primary" {
  provider             = aws.primary
  identifier           = "${local.name}-pri-1"
  cluster_identifier   = aws_rds_cluster.primary.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.primary.engine
  engine_version       = aws_rds_cluster.primary.engine_version
  db_subnet_group_name = module.primary.db_subnet_group_name
}

resource "aws_rds_cluster" "secondary" {
  provider                  = aws.secondary
  cluster_identifier        = "${local.name}-sec"
  global_cluster_identifier = aws_rds_global_cluster.this.id
  engine                    = aws_rds_global_cluster.this.engine
  engine_version            = aws_rds_global_cluster.this.engine_version
  db_subnet_group_name      = module.secondary.db_subnet_group_name
  vpc_security_group_ids    = [module.secondary.db_security_group_id]
  storage_encrypted         = true
  kms_key_id                = aws_kms_key.aurora_secondary.arn
  skip_final_snapshot       = true

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_acu
    max_capacity = var.aurora_max_acu
  }

  lifecycle {
    ignore_changes = [global_cluster_identifier, replication_source_identifier]
  }

  # The secondary can only join once the primary has a writer instance.
  depends_on = [aws_rds_cluster_instance.primary]
}

resource "aws_rds_cluster_instance" "secondary" {
  provider             = aws.secondary
  identifier           = "${local.name}-sec-1"
  cluster_identifier   = aws_rds_cluster.secondary.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.secondary.engine
  engine_version       = aws_rds_cluster.secondary.engine_version
  db_subnet_group_name = module.secondary.db_subnet_group_name
}
