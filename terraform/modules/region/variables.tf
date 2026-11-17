variable "name" {
  description = "Name prefix, e.g. dr-demo-primary."
  type        = string
}

variable "role" {
  description = "primary or secondary. Shown on the web page and used in tags."
  type        = string
}

variable "vpc_cidr" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "capacity" {
  type = object({
    min     = number
    desired = number
    max     = number
  })
}

variable "dynamodb_table_name" {
  description = "Global table the app writes visits to (each Region uses its local replica)."
  type        = string
}

variable "db_endpoint" {
  description = "Aurora endpoint shown on the status page (writer in primary, reader in secondary)."
  type        = string
  default     = ""
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN (local replica) holding the DB credentials."
  type        = string
}
