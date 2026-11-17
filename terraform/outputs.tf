output "app_url" {
  description = "Public URL (failover DNS name if configured, otherwise the primary ALB)."
  value       = var.hosted_zone_id == "" ? "http://${module.primary.alb_dns_name}" : "http://${var.app_domain_name}"
}

output "primary_region" {
  value = var.primary_region
}

output "secondary_region" {
  value = var.secondary_region
}

output "primary_alb_url" {
  value = "http://${module.primary.alb_dns_name}"
}

output "secondary_alb_url" {
  value = "http://${module.secondary.alb_dns_name}"
}

output "primary_asg_name" {
  value = module.primary.asg_name
}

output "secondary_asg_name" {
  value = module.secondary.asg_name
}

output "primary_health_check_id" {
  value = aws_route53_health_check.primary.id
}

output "aurora_global_cluster_id" {
  value = aws_rds_global_cluster.this.id
}

output "aurora_primary_writer_endpoint" {
  value = aws_rds_cluster.primary.endpoint
}

output "aurora_secondary_reader_endpoint" {
  value = aws_rds_cluster.secondary.reader_endpoint
}

output "aurora_secondary_cluster_arn" {
  value = aws_rds_cluster.secondary.arn
}

output "s3_primary_bucket" {
  value = aws_s3_bucket.primary.bucket
}

output "s3_secondary_bucket" {
  value = aws_s3_bucket.secondary.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.sessions.name
}

output "failover_lambda" {
  value = aws_lambda_function.failover.function_name
}
