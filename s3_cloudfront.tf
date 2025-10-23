# Create S3 bucket
resource "aws_s3_bucket" "frontend" {
  bucket = length(var.frontend_bucket_name) > 0 ? var.frontend_bucket_name : "${local.environment}-${local.service}-frontend-${random_id.bucket_suffix.hex}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "random_id" "bucket_suffix2" {
  byte_length = 4
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.environment}-${local.service}-oac-${local.region}"
  description                       = "OAC for ${local.environment}-${local.service} CloudFront to access S3 in ${local.region}"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
  origin_access_control_origin_type = "s3"
}

# Attach ACL separately
# Enable versioning
resource "aws_s3_bucket_versioning" "frontend_versioning" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Public-scan bucket + CloudFront (separate static site)
resource "aws_s3_bucket" "public_scan" {
  bucket = "${local.environment}-${local.service}-public-scan-${random_id.bucket_suffix2.hex}"

  tags = {
    Name = "${local.environment}-${local.service}-public-scan-${local.region}"
  }
}

resource "aws_s3_bucket_versioning" "public_scan_versioning" {
  bucket = aws_s3_bucket.public_scan.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_cloudfront_origin_access_control" "oac_public_scan" {
  name                              = "${local.environment}-${local.service}-oac-public-scan-${local.region}"
  description                       = "OAC for public-scan CloudFront to access S3 in ${local.region}"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
  origin_access_control_origin_type = "s3"
}

resource "aws_cloudfront_distribution" "public_scan_cdn" {
  origin {
    domain_name              = aws_s3_bucket.public_scan.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.public_scan.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac_public_scan.id
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.public_scan.id}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  http_version = "http2and3"

  tags = {
    Name = "${local.environment}-${local.service}-public-scan-cdn-${local.region}"
  }
}

# CloudFront distribution for S3 bucket
resource "aws_cloudfront_distribution" "frontend_cdn" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  default_root_object = var.frontend_index

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.frontend.id}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  http_version = "http2and3"

  tags = {
    Name = "${local.environment}-${local.service}-frontend-cdn-${local.region}"
  }
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend_cdn.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "public_scan_policy" {
  bucket = aws_s3_bucket.public_scan.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.public_scan.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.public_scan_cdn.arn
          }
        }
      }
    ]
  })
}
