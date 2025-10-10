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
  secret_id = var.db_secret_name
}

locals {
  effective_ami       = length(var.ami_id) > 0 ? var.ami_id : data.aws_ami.ubuntu.id
  rds_master_password = jsondecode(data.aws_secretsmanager_secret_version.db_secret.secret_string)["password"]
}
