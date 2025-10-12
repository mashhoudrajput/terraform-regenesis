locals {
  environment = terraform.workspace != "" ? terraform.workspace : var.environment
  service     = "regenesis"
  region      = var.aws_region
  # Note: use the pattern ${local.environment}-${local.service}-${component}-${local.region}
}
