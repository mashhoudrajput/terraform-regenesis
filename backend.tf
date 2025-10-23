terraform {
  backend "s3" {
    bucket         = "terraform-state-regenesis"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-regenesis"
    encrypt        = true
  }
}

