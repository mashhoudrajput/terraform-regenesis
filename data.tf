data "aws_availability_zones" "available" {}

# Ubuntu 22.04 LTS AMI (Canonical) - most recent
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_secretsmanager_secret_version" "db_secret" {
  count     = length(var.db_secret_name) > 0 ? 1 : 0
  secret_id = var.db_secret_name
}

resource "random_password" "rds_master" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "rds_generated" {
  count = length(var.db_secret_name) > 0 ? 0 : 1
  name  = "${local.environment}/rds-master-password"
}

resource "aws_secretsmanager_secret_version" "rds_generated_version" {
  count     = length(var.db_secret_name) > 0 ? 0 : 1
  secret_id = aws_secretsmanager_secret.rds_generated[0].id
  secret_string = jsonencode({
    username = var.db_username,
    password = random_password.rds_master.result
  })
}

locals {
  effective_ami       = length(var.ami_id) > 0 ? var.ami_id : data.aws_ami.ubuntu.id
  rds_master_password = length(var.db_secret_name) > 0 ? jsondecode(data.aws_secretsmanager_secret_version.db_secret[0].secret_string)["password"] : random_password.rds_master.result
}
