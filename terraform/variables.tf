variable "project_name" {
  description = "Prefix used for every resource name."
  type        = string
  default     = "dr-demo"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "prod"
}

variable "primary_region" {
  description = "Active Region."
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Warm-standby Region."
  type        = string
  default     = "eu-west-1"
}

variable "primary_vpc_cidr" {
  description = "CIDR of the primary VPC. Must not overlap the secondary VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "secondary_vpc_cidr" {
  description = "CIDR of the secondary VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for the web tier."
  type        = string
  default     = "t3.micro"
}

variable "primary_capacity" {
  description = "ASG sizing in the primary Region."
  type = object({
    min     = number
    desired = number
    max     = number
  })
  default = { min = 2, desired = 2, max = 4 }
}

variable "standby_capacity" {
  description = "ASG sizing in the secondary Region while it is on standby (warm standby = small but running)."
  type = object({
    min     = number
    desired = number
    max     = number
  })
  default = { min = 1, desired = 1, max = 4 }
}

variable "aurora_engine_version" {
  description = "Aurora MySQL version. Must support Global Database and Serverless v2."
  type        = string
  default     = "8.0.mysql_aurora.3.08.0"
}

variable "aurora_min_acu" {
  description = "Minimum Aurora Serverless v2 capacity (ACU)."
  type        = number
  default     = 0.5
}

variable "aurora_max_acu" {
  description = "Maximum Aurora Serverless v2 capacity (ACU)."
  type        = number
  default     = 4
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Aurora master user name. The password is generated and stored in Secrets Manager."
  type        = string
  default     = "dbadmin"
}

variable "hosted_zone_id" {
  description = "Route 53 public hosted zone ID. Leave empty to skip the failover DNS records (health check and automation still deploy)."
  type        = string
  default     = ""
}

variable "app_domain_name" {
  description = "FQDN users hit, e.g. app.example.com. Required when hosted_zone_id is set."
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email that receives failover notifications. Leave empty to skip the subscription."
  type        = string
  default     = ""
}

variable "auto_promote_database" {
  description = "If true, the failover Lambda also promotes the secondary Aurora cluster (unplanned failover, possible data loss up to the replication lag). If false, compute is scaled automatically and the DB is promoted by an operator with scripts/promote-secondary-db.sh."
  type        = bool
  default     = false
}

variable "health_check_failure_threshold" {
  description = "Consecutive failed Route 53 checks before the primary is marked unhealthy."
  type        = number
  default     = 3
}
