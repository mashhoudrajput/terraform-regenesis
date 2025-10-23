output "alb_dns" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.alb.dns_name
}

output "bastion_public_ip" {
  description = "Public IP address of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_eip" {
  description = "Elastic IP address of bastion host"
  value       = aws_eip.bastion_eip.public_ip
}

output "app_private_ip" {
  description = "Private IP address of primary app server"
  value       = aws_instance.app.private_ip
}

output "app2_private_ip" {
  description = "Private IP address of secondary app server (if created)"
  value       = var.create_app2 ? aws_instance.app2[0].private_ip : ""
}

output "queue_private_ip" {
  description = "Private IP address of queue server"
  value       = var.create_app2 ? aws_instance.app2[0].private_ip : ""
}

output "rds_cluster_endpoint" {
  description = "RDS Aurora cluster writer endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "rds_cluster_reader_endpoint" {
  description = "RDS Aurora cluster reader endpoint"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "frontend_bucket" {
  description = "S3 bucket name for frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "public_scan_bucket" {
  description = "S3 bucket name for public scan"
  value       = aws_s3_bucket.public_scan.bucket
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain for frontend"
  value       = aws_cloudfront_distribution.frontend_cdn.domain_name
}

output "cloudfront_public_scan_domain" {
  description = "CloudFront distribution domain for public scan"
  value       = aws_cloudfront_distribution.public_scan_cdn.domain_name
}

output "jump_public_key" {
  description = "SSH jump host public key deployed to app servers"
  value       = tls_private_key.jump.public_key_openssh
  sensitive   = true
}

output "ecr_api_url" {
  description = "ECR repository URL for API"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_queue_url" {
  description = "ECR repository URL for queue worker"
  value       = aws_ecr_repository.queue.repository_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "environment" {
  description = "Environment name"
  value       = local.environment
}

