locals {
  environment = terraform.workspace != "" ? terraform.workspace : var.environment
  name_prefix = "${local.environment}-regenesis"
}
