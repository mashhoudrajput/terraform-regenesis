terraform {
  backend "s3" {
    bucket = "terraform-state-mashhoud"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

