data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${local.environment}-${local.service}-ec2-role-${local.region}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Name        = "${local.environment}-${local.service}-ec2-role-${local.region}"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ecr_access" {
  name = "${local.environment}-${local.service}-ec2-ecr-policy-${local.region}"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.environment}-${local.service}-ec2-profile-${local.region}"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "${local.environment}-${local.service}-ec2-profile-${local.region}"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}
