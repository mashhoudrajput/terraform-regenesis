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

locals {
  effective_ami = length(var.ami_id) > 0 ? var.ami_id : data.aws_ami.ubuntu.id
}
