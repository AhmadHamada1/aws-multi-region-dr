output "vpc_id" {
  value = aws_vpc.this.id
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "alb_zone_id" {
  value = aws_lb.app.zone_id
}

output "alb_arn_suffix" {
  value = aws_lb.app.arn_suffix
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "asg_arn" {
  value = aws_autoscaling_group.app.arn
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.this.name
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}
