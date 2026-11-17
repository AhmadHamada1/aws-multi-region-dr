# AWS Backup: a last line of defence for data corruption or accidental deletes,
# which replication would happily copy to the other Region.
# Daily backups in the primary Region, copied to a vault in the secondary Region.

resource "aws_backup_vault" "primary" {
  provider      = aws.primary
  name          = "${local.name}-vault"
  force_destroy = true
}

resource "aws_backup_vault" "secondary" {
  provider      = aws.secondary
  name          = "${local.name}-vault"
  force_destroy = true
}

resource "aws_backup_plan" "daily" {
  provider = aws.primary
  name     = "${local.name}-daily"

  rule {
    rule_name         = "daily-35d"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 3 * * ? *)"

    lifecycle {
      delete_after = 35
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.secondary.arn
      lifecycle {
        delete_after = 35
      }
    }
  }
}

resource "aws_iam_role" "backup" {
  provider = aws.primary
  name     = "${local.name}-backup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  provider   = aws.primary
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  provider   = aws.primary
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Everything tagged Backup=true (Aurora primary cluster, DynamoDB table).
resource "aws_backup_selection" "tagged" {
  provider     = aws.primary
  name         = "${local.name}-tagged"
  plan_id      = aws_backup_plan.daily.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }
}
