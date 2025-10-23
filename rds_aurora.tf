##########################################
# RDS Aurora MySQL Cluster
##########################################

# DB Subnet Group
resource "aws_db_subnet_group" "aurora" {
  name = "${local.environment}-${local.service}-aurora-subnet-group-${local.region}"
  subnet_ids = [
    element(values(aws_subnet.private), 0).id,
    element(values(aws_subnet.private), 1).id
  ]

  tags = {
    Name = "${local.environment}-${local.service}-aurora-subnet-group-${local.region}"
  }
}

# Aurora Cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier        = "${local.environment}-${local.service}-aurora-${local.region}"
  engine                    = var.db_engine
  engine_version            = var.db_engine_version
  master_username           = var.db_username
  master_password           = var.db_password
  database_name             = var.db_name
  db_subnet_group_name      = aws_db_subnet_group.aurora.name
  vpc_security_group_ids    = [aws_security_group.rds_sg.id]
  storage_encrypted         = true
  backup_retention_period   = 1 # Minimum allowed for Aurora MySQL
  preferred_backup_window   = "02:00-03:00"
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.environment}-${local.service}-aurora-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = {
    Name        = "${local.environment}-${local.service}-aurora-cluster-${local.region}"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

# Aurora Cluster Instance
resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier          = "${local.environment}-${local.service}-aurora-instance-1-${local.region}"
  cluster_identifier  = aws_rds_cluster.aurora.id
  instance_class      = var.rds_instance_class
  engine              = var.db_engine
  publicly_accessible = false

  tags = {
    Name        = "${local.environment}-${local.service}-aurora-instance-${local.region}"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}
