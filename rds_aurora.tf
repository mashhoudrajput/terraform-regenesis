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
  cluster_identifier      = "${local.environment}-${local.service}-aurora-${local.region}"
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.08.2"
  master_username         = var.db_username
  master_password         = local.rds_master_password
  database_name           = var.db_name
  db_subnet_group_name    = aws_db_subnet_group.aurora.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  storage_encrypted       = true
  backup_retention_period = 1
  preferred_backup_window = "02:00-03:00"
  skip_final_snapshot     = true

  tags = {
    Name = "${local.environment}-${local.service}-aurora-cluster-${local.region}"
  }
}

# Aurora Cluster Instance
resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier          = "${local.environment}-${local.service}-aurora-instance-1-${local.region}"
  cluster_identifier  = aws_rds_cluster.aurora.id
  instance_class      = "db.t3.medium"
  engine              = "aurora-mysql"
  publicly_accessible = false

  tags = {
    Name = "${local.environment}-${local.service}-aurora-instance-${local.region}"
  }
}
