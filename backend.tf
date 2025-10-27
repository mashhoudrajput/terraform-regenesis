terraform {
  backend "s3" {
    bucket         = "terraform-state-regenesis-110836100128"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-regenesis"
    encrypt        = true
  }
}

