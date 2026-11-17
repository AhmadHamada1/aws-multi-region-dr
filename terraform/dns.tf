# Route 53 health check on the primary ALB. Route 53 health checkers run from
# many locations worldwide, so detection keeps working even if the primary
# Region is down.

resource "aws_route53_health_check" "primary" {
  provider          = aws.primary
  fqdn              = module.primary.alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  request_interval  = 10 # fast checks: ~30s to detect with threshold 3
  failure_threshold = var.health_check_failure_threshold
  measure_latency   = true

  tags = { Name = "${local.name}-primary-alb" }
}

resource "aws_route53_health_check" "secondary" {
  provider          = aws.primary
  fqdn              = module.secondary.alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  request_interval  = 30
  failure_threshold = 3

  tags = { Name = "${local.name}-secondary-alb" }
}

# Failover routing: answer with PRIMARY while it is healthy, otherwise SECONDARY.
# Low TTL so resolvers pick up the change quickly (alias records use the ALB's 60s TTL).

resource "aws_route53_record" "primary" {
  count    = var.hosted_zone_id == "" ? 0 : 1
  provider = aws.primary

  zone_id         = var.hosted_zone_id
  name            = var.app_domain_name
  type            = "A"
  set_identifier  = "primary-${var.primary_region}"
  health_check_id = aws_route53_health_check.primary.id

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = module.primary.alb_dns_name
    zone_id                = module.primary.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "secondary" {
  count    = var.hosted_zone_id == "" ? 0 : 1
  provider = aws.primary

  zone_id         = var.hosted_zone_id
  name            = var.app_domain_name
  type            = "A"
  set_identifier  = "secondary-${var.secondary_region}"
  health_check_id = aws_route53_health_check.secondary.id

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = module.secondary.alb_dns_name
    zone_id                = module.secondary.alb_zone_id
    evaluate_target_health = true
  }
}
