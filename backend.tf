terraform {
  backend "s3" {
    bucket = "terraform-state-beta-regenesis"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

