output "alb_dns" {
  value = aws_lb.alb.dns_name
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "app_private_ip" {
  value = aws_instance.app.private_ip
}

output "rds_cluster_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "frontend_bucket" {
  value = aws_s3_bucket.frontend.bucket
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.frontend_cdn.domain_name
}

