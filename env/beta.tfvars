# Beta Environment Configuration

# AWS Configuration
aws_region  = "us-east-1"
aws_profile = "default" # Update to your AWS CLI profile name

# Environment
environment = "beta"

# VPC Configuration
vpc_cidr        = "10.4.0.0/16"
public_subnets  = ["10.4.1.0/24", "10.4.2.0/24"]
private_subnets = ["10.4.11.0/24", "10.4.12.0/24"]

# Networking
create_nat_gateway = true # Enable NAT Gateway for internet access

# SSH Configuration
ssh_key_name        = "beta-regenesis-keypair"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Compute Resources
bastion_instance_type = "t3.micro"
app_instance_type     = "t3.micro"
create_app2           = true        # Enable queue server
bastion_allowed_cidr  = "0.0.0.0/0" # Restrict in production

# Database Configuration
rds_instance_class = "db.t3.medium"
db_username        = "admin"
db_name            = "regenesis_beta"
db_password        = "TempPassword123!ChangeAfterDeploy"
# Note: After deployment, manually migrate to AWS Secrets Manager via RDS console

# S3 Configuration
frontend_bucket_name = "" # Auto-generate
