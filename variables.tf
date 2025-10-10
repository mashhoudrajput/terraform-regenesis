variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "AWS access key for this env"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key for this env"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "env name (dev|staging|prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "ssh_key_name" {
  type    = string
  default = "dev-keypair"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "ami_id" {
  type    = string
  default = ""
}

variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "app_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "db_cluster_identifier" {
  type    = string
  default = "dev-aurora"
}

variable "db_engine" {
  type    = string
  default = "aurora-mysql"
}

variable "db_engine_version" {
  type    = string
  default = "8.0.mysql_aurora.3.04.0"
}

variable "db_username" {
  type    = string
  default = "appadmin"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "db_secret_name" {
  description = "Name/ARN of an existing Secrets Manager secret that contains the DB credentials (JSON with username and password)"
  type        = string
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.small"
}

variable "frontend_bucket_name" {
  type    = string
  default = ""
}

variable "frontend_index" {
  type    = string
  default = "index.html"
}

variable "create_nat_gateway" {
  type    = bool
  default = true
}

variable "bastion_allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
