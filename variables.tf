# AWS Configuration
variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name to use for authentication"
  type        = string
  default     = "default"
}

# Environment Configuration
variable "environment" {
  description = "Environment name (qa|beta|prod)"
  type        = string
  validation {
    condition     = contains(["qa", "beta", "prod"], var.environment)
    error_message = "Environment must be one of: qa, beta, prod."
  }
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "create_nat_gateway" {
  description = "Whether to create NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
}

# Compute Configuration
variable "ssh_key_name" {
  description = "Name for SSH key pair"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (leave empty to auto-select Ubuntu 22.04 LTS)"
  type        = string
  default     = ""
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "app_instance_type" {
  description = "Instance type for application servers"
  type        = string
  default     = "t3.small"
}

variable "create_app2" {
  description = "Whether to create a second app instance (queue/worker)"
  type        = bool
  default     = false
}

variable "bastion_allowed_cidr" {
  description = "CIDR block allowed to SSH into bastion host"
  type        = string
  default     = "0.0.0.0/0"
}

# Database Configuration
variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "aurora-mysql"
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0.mysql_aurora.3.08.2"
}

variable "db_username" {
  description = "Master username for database"
  type        = string
  default     = "appadmin"
}

variable "db_password" {
  description = "Master password for database (use strong password, min 8 characters)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters long."
  }
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "rds_instance_class" {
  description = "RDS Aurora instance class"
  type        = string
  default     = "db.t3.medium"
}

# S3 and CloudFront Configuration
variable "frontend_bucket_name" {
  description = "Name for frontend S3 bucket (leave empty to auto-generate)"
  type        = string
  default     = ""
}

variable "frontend_index" {
  description = "Index document for frontend"
  type        = string
  default     = "index.html"
}
