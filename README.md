# Regenesis Infrastructure - Terraform

Professional AWS infrastructure for the Regenesis application, supporting multiple environments (QA, Beta, Production) with Infrastructure as Code.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Pre-Deployment Setup](#pre-deployment-setup)
- [Deployment Instructions](#deployment-instructions)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Infrastructure Destruction](#infrastructure-destruction)
- [Environment Management](#environment-management)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## 🏗️ Architecture Overview

This Terraform configuration deploys a secure, scalable AWS infrastructure with:

### Infrastructure Components

- **VPC**: Multi-AZ Virtual Private Cloud with public and private subnets
- **Compute**: 
  - Bastion host (t3.micro) for secure SSH access with automated jump key configuration
  - API server (t3.micro) with AWS CLI and Docker pre-installed
  - Queue server (t3.micro) for background job processing with AWS CLI and Docker
  - 4GB swap configured on all servers
- **Database**: Aurora MySQL 8.0 cluster (db.t3.medium) with 1-day backup retention
- **Load Balancing**: Application Load Balancer (ALB) distributing traffic to API server only
- **CDN**: CloudFront distributions for frontend and public-scan static sites
- **Storage**: S3 buckets with versioning enabled
- **Container Registry**: ECR repositories for Docker images with lifecycle policies (keep last 10 images)
- **Security**: Security groups, IAM roles, encrypted storage
- **SSH Automation**: Automated jump host configuration via AWS Systems Manager (ED25519 keys)
- **VPC Endpoints**: SSM endpoints for private instance connectivity without NAT Gateway dependency
- **NAT Gateway**: Enabled in all environments for internet access from private subnets

### Environments

All three environments are configured identically with the same resources and instance types for consistency. Only VPC CIDR blocks and database names differ.

| Environment | VPC CIDR     | Purpose                    | Compute Instances | RDS Instance    | NAT Gateway |
|-------------|--------------|----------------------------|-------------------|-----------------|-------------|
| QA          | 10.1.0.0/16  | Quality Assurance Testing  | 3 × t3.micro      | db.t3.medium    | ✅ Enabled  |
| Beta        | 10.4.0.0/16  | Pre-production staging     | 3 × t3.micro      | db.t3.medium    | ✅ Enabled  |
| Production  | 10.3.0.0/16  | Live production workload   | 3 × t3.micro      | db.t3.medium    | ✅ Enabled  |

**Compute Instances:**
- 1 × Bastion host (t3.micro) - Public subnet with Elastic IP
- 1 × API Server (t3.micro) - Private subnet, attached to ALB
- 1 × Queue Server (t3.micro) - Private subnet, background processing only

## ✅ Prerequisites

### Required Software

1. **Terraform** >= 1.0
   ```bash
   # Verify installation
   terraform version
   ```

2. **AWS CLI** >= 2.0
   ```bash
   # Verify installation
   aws --version
   ```

3. **SSH Key Pair**
   ```bash
   # Generate if you don't have one
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
   ```

### AWS Requirements

- AWS Account with appropriate permissions
- IAM user or role with admin access (or specific permissions for EC2, VPC, RDS, S3, CloudFront, ECR, IAM)
- AWS CLI configured with credentials

### Resource Quotas

Ensure your AWS account has sufficient service quotas:
- VPCs: 5 per region
- Elastic IPs: 5 per region
- EC2 Instances: 20 per region
- RDS Clusters: 5 per region

## 🚀 Pre-Deployment Setup

### Step 1: Configure AWS Credentials

Set up an AWS CLI profile for your environment:

```bash
# Configure AWS profile
aws configure --profile regenesis

# Test the profile
aws sts get-caller-identity --profile regenesis
```

Update the profile name in your environment's `.tfvars` file.

### Step 2: Create Backend Resources

Before deploying infrastructure, create the S3 bucket and DynamoDB table for Terraform state management:

```bash
# Set your environment
export ENV=qa  # or beta, prod

# Create S3 bucket for Terraform state
aws s3 mb s3://terraform-state-regenesis --region us-east-1

# Enable versioning on the S3 bucket
aws s3api put-bucket-versioning \
  --bucket terraform-state-regenesis \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket terraform-state-regenesis \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket terraform-state-regenesis \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock-regenesis \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 3: Configure Database Password

The database password is configured in each environment's `.tfvars` file:

```bash
# Edit the environment-specific tfvars file
vim env/qa.tfvars  # or beta.tfvars, prod.tfvars

# Update the db_password field:
# db_password = "YourSecurePassword123!ChangeAfterDeploy"
```

**Password Requirements:**
- Minimum 8 characters
- Include uppercase, lowercase, numbers, and special characters
- Avoid dictionary words or common patterns

**⚠️ Important:** After deployment, manually migrate the password to AWS Secrets Manager:
1. Go to AWS RDS Console
2. Select your Aurora cluster
3. Modify → Manage master credentials in AWS Secrets Manager
4. Update your application configuration to use Secrets Manager

### Step 4: Update Configuration Files

1. **Review and update** `env/qa.tfvars` (or beta/prod):
   - Set `aws_profile` to your AWS CLI profile name
   - Update `ssh_public_key_path` if not using default location
   - For production, update `bastion_allowed_cidr` to your IP address

2. **Verify backend configuration** in `backend.tf`:
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "terraform-state-regenesis"
       key            = "terraform.tfstate"
       region         = "us-east-1"
       dynamodb_table = "terraform-state-lock-regenesis"
       encrypt        = true
     }
   }
   ```

## 🚀 Deployment Instructions

### Step 1: Initialize Terraform

```bash
# Navigate to the project directory
cd /path/to/terraform-regenesis

# Initialize Terraform (downloads providers and sets up backend)
terraform init
```

Expected output: `Terraform has been successfully initialized!`

### Step 2: Select Environment

```bash
# Set environment variable for easier command execution
export ENV=qa  # or beta, prod

# Verify the configuration
cat env/${ENV}.tfvars
```

### Step 3: Plan Deployment

Review what Terraform will create:

```bash
# Create an execution plan
terraform plan -var-file=env/${ENV}.tfvars -out=${ENV}.tfplan

# Review the plan output carefully
# Verify resource counts and configurations
```

**Review Checklist:**
- [ ] Correct VPC CIDR blocks
- [ ] Appropriate instance types for environment
- [ ] NAT Gateway enabled/disabled as expected
- [ ] Database instance class matches requirements
- [ ] Security group rules are appropriate

### Step 4: Apply Configuration

```bash
# Apply the planned changes
terraform apply ${ENV}.tfplan

# This will take approximately 15-20 minutes
# Aurora cluster creation is the longest step (~10-15 minutes)
```

**What's Being Created:**
1. VPC and networking (2-3 minutes)
2. Security groups (1 minute)
3. EC2 instances (3-5 minutes)
4. RDS Aurora cluster (10-15 minutes)
5. Load balancer (2-3 minutes)
6. S3 and CloudFront (3-5 minutes)
7. ECR repositories (1 minute)
8. SSH jump host automation (2 minutes)

### Step 5: Verify Deployment

```bash
# View outputs
terraform output

# Test connectivity to bastion
terraform output bastion_public_ip
ssh ubuntu@$(terraform output -raw bastion_public_ip)

# Check ALB health
curl http://$(terraform output -raw alb_dns)
```

## ⚙️ Post-Deployment Configuration

### 1. Verify Infrastructure

#### EC2 Instances

```bash
# List EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=${ENV}" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

#### RDS Cluster

```bash
# Get RDS cluster status
aws rds describe-db-clusters \
  --query 'DBClusters[*].[DBClusterIdentifier,Status,Endpoint]' \
  --output table

# Get RDS endpoint from Terraform
terraform output rds_cluster_endpoint
```

#### Load Balancer

```bash
# Get ALB status
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[*].[LoadBalancerName,State.Code,DNSName]' \
  --output table

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --query 'TargetGroups[0].TargetGroupArn' --output text)
```

### 2. Configure Application

#### Connect to Application Servers

SSH access is automated with jump keys and aliases:

```bash
# Get the bastion IP
BASTION_IP=$(terraform output -raw bastion_public_ip)

# SSH to bastion
ssh ubuntu@${BASTION_IP}

# From bastion, connect to API server (jump key is auto-deployed)
ssh ubuntu@$(terraform output -raw app_private_ip)

# Or connect to Queue server
ssh ubuntu@$(terraform output -raw queue_private_ip)
```

**Note:** The bastion has SSH jump keys automatically configured via AWS Systems Manager. You can also use SSH aliases on the bastion (if configured):
```bash
# From bastion (if SSH config aliases are set up manually)
ssh api    # Connects to API server
ssh queue  # Connects to Queue server
```

#### Deploy Application Code

AWS CLI and Docker are pre-installed on API and Queue servers:

```bash
# On the API server, pull your application code
cd /home/ubuntu
git clone https://github.com/your-org/regenesis-app.git

# Docker and AWS CLI are pre-installed - use ECR to pull images
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_api_url)
docker pull $(terraform output -raw ecr_api_url):latest
docker run -d -p 3000:3000 $(terraform output -raw ecr_api_url):latest

# For Queue server, deploy queue worker
ssh ubuntu@$(terraform output -raw queue_private_ip)
cd /home/ubuntu
docker pull $(terraform output -raw ecr_queue_url):latest
docker run -d $(terraform output -raw ecr_queue_url):latest
```

### 3. Database Setup

#### Connect to Database

```bash
# From bastion or app server
mysql -h $(terraform output -raw rds_cluster_endpoint) -u admin -p

# Enter the password you set in the .tfvars file
# Default database names:
# - regenesis_qa (QA environment)
# - regenesis_beta (Beta environment)
# - regenesis_prod (Production environment)
```

#### Initialize Database

```sql
-- Create application tables
USE regenesis_qa;

-- Run your schema migrations
SOURCE /path/to/schema.sql;

-- Verify tables
SHOW TABLES;
```

### 4. Upload Frontend to S3

```bash
# Build your frontend application
cd /path/to/frontend
npm run build

# Get bucket name
BUCKET=$(terraform output -raw frontend_bucket)

# Upload to S3
aws s3 sync ./dist s3://${BUCKET}/ --delete

# Invalidate CloudFront cache
DISTRIBUTION_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='${ENV}-regenesis-frontend-cdn'].Id" \
  --output text)

aws cloudfront create-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --paths "/*"
```

### 5. Configure DNS (Optional)

If you have a custom domain:

```bash
# Get CloudFront domain
terraform output cloudfront_domain

# Create CNAME record in Route53 or your DNS provider
# app.example.com -> d1234567890.cloudfront.net
```

### 6. Set Up Monitoring

```bash
# Enable CloudWatch detailed monitoring
aws ec2 monitor-instances --instance-ids $(terraform output -json | jq -r '.app_private_ip.value')

# Create CloudWatch alarms (example)
aws cloudwatch put-metric-alarm \
  --alarm-name "${ENV}-regenesis-high-cpu" \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## 🗑️ Infrastructure Destruction

### Pre-Deletion Checklist

Before destroying infrastructure, ensure:

- [ ] All important data is backed up
- [ ] S3 buckets are empty or you have copies of important files
- [ ] Database final snapshot is enabled (or manually take snapshot)
- [ ] No critical applications are running
- [ ] Team is notified of the destruction
- [ ] DNS records are updated or removed

### Step 1: Prepare for Destruction

```bash
# Set environment
export ENV=qa  # or beta, prod

# Create database snapshot (recommended)
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier ${ENV}-regenesis-aurora-us-east-1 \
  --db-cluster-snapshot-identifier ${ENV}-regenesis-manual-snapshot-$(date +%Y%m%d)

# Empty S3 buckets (required for deletion)
FRONTEND_BUCKET=$(terraform output -raw frontend_bucket)
PUBLIC_SCAN_BUCKET=$(terraform output -raw public_scan_bucket 2>/dev/null || echo "")

# Delete all objects and versions
aws s3 rm s3://${FRONTEND_BUCKET} --recursive
aws s3api delete-objects --bucket ${FRONTEND_BUCKET} \
  --delete "$(aws s3api list-object-versions --bucket ${FRONTEND_BUCKET} --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"

# Repeat for public_scan bucket if it exists
if [ -n "$PUBLIC_SCAN_BUCKET" ]; then
  aws s3 rm s3://${PUBLIC_SCAN_BUCKET} --recursive
  aws s3api delete-objects --bucket ${PUBLIC_SCAN_BUCKET} \
    --delete "$(aws s3api list-object-versions --bucket ${PUBLIC_SCAN_BUCKET} --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"
fi

# Empty ECR repositories
aws ecr batch-delete-image \
  --repository-name ${ENV}-regenesis-api \
  --image-ids "$(aws ecr list-images --repository-name ${ENV}-regenesis-api --query 'imageIds[*]' --output json)" 2>/dev/null || true

aws ecr batch-delete-image \
  --repository-name ${ENV}-regenesis-queue \
  --image-ids "$(aws ecr list-images --repository-name ${ENV}-regenesis-queue --query 'imageIds[*]' --output json)" 2>/dev/null || true
```

### Step 2: Plan Destruction

```bash
# Review what will be destroyed
terraform plan -destroy -var-file=env/${ENV}.tfvars

# Carefully review the list of resources to be destroyed
```

### Step 3: Destroy Infrastructure

```bash
# Destroy all resources
terraform destroy -var-file=env/${ENV}.tfvars

# Confirm by typing 'yes' when prompted
# This will take approximately 10-15 minutes
```

**Destruction Order:**
1. EC2 instances and load balancers (3-5 minutes)
2. RDS cluster (if skip_final_snapshot=false, takes snapshot first ~5 minutes)
3. VPC and networking components (2-3 minutes)
4. S3 buckets and CloudFront distributions (3-5 minutes)
5. IAM roles and policies (1 minute)

### Step 4: Verify Deletion

```bash
# Verify all resources are deleted
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=${ENV}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
  --output table

# Check for remaining resources
terraform show
```

### Step 5: Clean Up State Files (Optional)

```bash
# Remove local state files
rm -rf .terraform/
rm terraform.tfstate*
rm *.tfplan

# The remote state in S3 is preserved for audit purposes
# Only delete it if you're certain you won't need it
# aws s3 rm s3://terraform-state-regenesis/terraform.tfstate
```

### Troubleshooting Destruction Issues

#### S3 Bucket Not Empty
```bash
# Force delete all versions
aws s3api delete-bucket --bucket ${BUCKET_NAME} --force
```

#### RDS Cluster Won't Delete
```bash
# Remove deletion protection
aws rds modify-db-cluster \
  --db-cluster-identifier ${CLUSTER_ID} \
  --no-deletion-protection \
  --apply-immediately

# Try destroy again
terraform destroy -var-file=env/${ENV}.tfvars
```

#### Resources Still Exist
```bash
# Target specific resources for destruction
terraform destroy -target=aws_instance.app -var-file=env/${ENV}.tfvars
terraform destroy -target=aws_rds_cluster.aurora -var-file=env/${ENV}.tfvars
```

## 🔧 Environment Management

### All Three Environments Are Identical

All environments (QA, Beta, Production) use the **same infrastructure configuration** with identical resources:
- **Compute**: 3 × t3.micro (Bastion, API, Queue)
- **Database**: Aurora MySQL db.t3.medium
- **NAT Gateway**: Enabled in all environments
- **Software**: AWS CLI and Docker pre-installed
- **ALB**: Configured for API server only

**What Differs:**
- VPC CIDR blocks (10.1.x.x, 10.4.x.x, 10.3.x.x)
- SSH key names
- Database names (regenesis_qa, regenesis_beta, regenesis_prod)
- Database passwords

### Deploying Each Environment

```bash
# ===== DEPLOY QA ENVIRONMENT =====
export ENV=qa
terraform plan -var-file=env/${ENV}.tfvars -out=${ENV}.tfplan
terraform apply ${ENV}.tfplan
# Verify: terraform output -json

# ===== DEPLOY BETA ENVIRONMENT =====
export ENV=beta
terraform plan -var-file=env/${ENV}.tfvars -out=${ENV}.tfplan
terraform apply ${ENV}.tfplan
# Verify: terraform output -json

# ===== DEPLOY PRODUCTION ENVIRONMENT =====
export ENV=prod
terraform plan -var-file=env/${ENV}.tfvars -out=${ENV}.tfplan
terraform apply ${ENV}.tfplan
# Verify: terraform output -json
```

### Managing Multiple Environments Simultaneously

Each environment is isolated with:
- ✅ Separate VPC CIDR blocks (no IP conflicts)
- ✅ Unique resource names (prefixed with environment: `qa-`, `beta-`, `prod-`)
- ✅ Independent state management (shared backend, isolated states)
- ✅ Separate SSH keys (unique per environment)
- ✅ Isolated databases (different cluster names)

You can have **all three environments running simultaneously** without any conflicts or interference.

### Promoting Changes Between Environments

**Best Practice Workflow:**

1. **Develop & Test in QA** 
   ```bash
   terraform apply -var-file=env/qa.tfvars
   # Test your application changes
   ```

2. **Validate in Beta** 
   ```bash
   terraform apply -var-file=env/beta.tfvars
   # Perform integration testing
   ```

3. **Deploy to Production**
   ```bash
   terraform apply -var-file=env/prod.tfvars
   # Monitor and verify
   ```

4. **Infrastructure Changes**
   - Infrastructure changes (Terraform code) apply to ALL environments
   - Only environment-specific values (in `.tfvars`) differ
   - Update all environments when infrastructure changes

### Environment-Specific Outputs

```bash
# Get outputs for specific environment
terraform output -var-file=env/qa.tfvars

# Save environment-specific outputs
terraform output -json -var-file=env/qa.tfvars > outputs_qa.json
terraform output -json -var-file=env/beta.tfvars > outputs_beta.json
terraform output -json -var-file=env/prod.tfvars > outputs_prod.json
```

## 🐛 Troubleshooting

### Common Issues

#### Issue: Terraform init fails

```bash
# Check backend configuration
cat backend.tf

# Verify S3 bucket exists
aws s3 ls terraform-state-regenesis

# Verify you have access
aws s3 ls s3://terraform-state-regenesis/
```

#### Issue: Authentication errors

```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify profile
echo $AWS_PROFILE

# Test with specific profile
aws sts get-caller-identity --profile regenesis
```

#### Issue: Resource quota exceeded

```bash
# Check EC2 limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A

# Request limit increase via AWS Console
```

#### Issue: RDS cluster creation fails

```bash
# Check available AZs
aws rds describe-orderable-db-instance-options \
  --engine aurora-mysql \
  --engine-version 8.0.mysql_aurora.3.08.2 \
  --query 'OrderableDBInstanceOptions[*].[DBInstanceClass,AvailabilityZones[0].Name]' \
  --output table

# Ensure subnets span multiple AZs
```

#### Issue: SSH connection refused to bastion

```bash
# Wait for instance to be fully initialized
aws ec2 describe-instance-status --instance-ids ${INSTANCE_ID}

# Check security group
aws ec2 describe-security-groups --group-ids ${SG_ID}

# Verify SSH key
ssh-add -l
```

#### Issue: ALB targets unhealthy

```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn ${TG_ARN}

# Check app server logs
ssh ubuntu@${BASTION_IP}
ssh ubuntu@${APP_IP}
journalctl -u app -f

# Verify security group allows ALB traffic on port 3000
```

### Getting Help

1. Check Terraform logs:
   ```bash
   export TF_LOG=DEBUG
   terraform apply -var-file=env/${ENV}.tfvars
   ```

2. Review AWS CloudWatch logs

3. Check AWS CloudTrail for API errors

4. Review Terraform state:
   ```bash
   terraform show
   terraform state list
   ```

## 📚 Best Practices

### Security

1. **Never commit sensitive data**
   - `.tfvars` files with passwords are gitignored
   - Migrate DB passwords to AWS Secrets Manager after deployment
   - Use AWS Secrets Manager for application secrets
   - Never commit actual passwords to version control

2. **Restrict access**
   - Limit bastion SSH access to known IPs (update `bastion_allowed_cidr` in `.tfvars`)
   - Use IAM roles instead of access keys where possible
   - Enable MFA on AWS accounts
   - Internal VPC traffic uses security groups (not open to internet)

3. **Enable encryption**
   - All RDS storage is encrypted at rest
   - S3 buckets use server-side encryption (AES256)
   - Terraform state is encrypted in S3
   - Enable encryption in transit (HTTPS/TLS)

4. **Regular updates**
   - Keep Terraform and providers updated
   - Apply security patches to EC2 instances (`apt update && apt upgrade`)
   - Rotate database passwords regularly (migrate to Secrets Manager)
   - Review and update AMIs periodically

### Cost Optimization

1. **Right-size resources**
   - All environments use t3.micro instances (cost-efficient)
   - Consider t3.small or t3.medium for production if needed
   - Monitor CPU/memory usage to avoid over-provisioning

2. **Manage non-production environments**
   - Destroy QA/Beta when not in use (save ~$150-200/month per environment)
   - Schedule shutdowns after hours using AWS Instance Scheduler
   - NAT Gateway costs ~$32/month per environment (enabled in all by default)

3. **Monitor costs**
   - Set up AWS Budgets alerts (recommended: $200/month per environment)
   - Review Cost Explorer monthly
   - All resources are tagged with Environment, Project, and ManagedBy tags

4. **Estimated monthly costs per environment**
   - EC2 instances (3 × t3.micro): ~$30/month
   - RDS Aurora (db.t3.medium): ~$85/month
   - NAT Gateway: ~$32/month
   - ALB: ~$22/month
   - S3 & CloudFront: ~$5-10/month (varies with usage)
   - **Total per environment**: ~$175-180/month base cost

### Reliability

1. **Backup strategy**
   - RDS automated backups enabled (1-day retention, increase for production)
   - S3 versioning enabled on all buckets
   - RDS final snapshots enabled before destruction
   - Regular disaster recovery testing

2. **Monitoring**
   - Set up CloudWatch alarms for CPU, memory, disk
   - Enable detailed monitoring in production
   - Use SSM Session Manager for secure access (no SSH keys needed)
   - Log aggregation and analysis with CloudWatch Logs

3. **High availability**
   - Multi-AZ capable (currently single-AZ for cost)
   - NAT Gateway enabled for internet access
   - VPC Endpoints for SSM (no dependency on NAT for management)
   - CloudFront for global CDN availability
   - ALB distributes traffic across availability zones

### Development Workflow

1. **Always plan before apply**
   ```bash
   terraform plan -out=plan.tfplan
   # Review carefully
   terraform apply plan.tfplan
   ```

2. **Use version control**
   - Commit all Terraform code to git
   - Use branches for testing changes
   - Require code review for production changes

3. **Document changes**
   - Update comments in code
   - Maintain changelog
   - Document any manual changes

4. **Test in lower environments**
   - QA → Beta → Production
   - Never test directly in production
   - Validate thoroughly before promoting

## 🚀 Quick Reference - All Environments

### Environment Comparison

| Aspect              | QA                      | Beta                      | Production                 |
|---------------------|-------------------------|---------------------------|----------------------------|
| **VPC CIDR**        | 10.1.0.0/16            | 10.4.0.0/16              | 10.3.0.0/16                |
| **Database Name**   | regenesis_qa           | regenesis_beta           | regenesis_prod             |
| **SSH Key**         | qa-regenesis-keypair   | beta-regenesis-keypair   | prod-regenesis-keypair     |
| **Compute**         | 3 × t3.micro           | 3 × t3.micro             | 3 × t3.micro               |
| **RDS**             | db.t3.medium           | db.t3.medium             | db.t3.medium               |
| **NAT Gateway**     | ✅ Enabled             | ✅ Enabled               | ✅ Enabled                 |

### Quick Commands Reference

```bash
# ============== DEPLOYMENT ==============
# QA
terraform apply -var-file=env/qa.tfvars -auto-approve

# Beta
terraform apply -var-file=env/beta.tfvars -auto-approve

# Production
terraform apply -var-file=env/prod.tfvars -auto-approve

# ============== VERIFICATION ==============
# Get outputs for any environment
terraform output -var-file=env/qa.tfvars
terraform output -var-file=env/beta.tfvars
terraform output -var-file=env/prod.tfvars

# ============== SSH ACCESS ==============
# QA
ssh ubuntu@$(terraform output -raw bastion_public_ip)

# Beta (after switching context)
terraform output -var-file=env/beta.tfvars -raw bastion_public_ip
ssh ubuntu@<BETA_BASTION_IP>

# Production
terraform output -var-file=env/prod.tfvars -raw bastion_public_ip
ssh ubuntu@<PROD_BASTION_IP>

# ============== DESTRUCTION ==============
# QA
terraform destroy -var-file=env/qa.tfvars -auto-approve

# Beta
terraform destroy -var-file=env/beta.tfvars -auto-approve

# Production (be very careful!)
terraform destroy -var-file=env/prod.tfvars
```

### Resource Naming Convention

All resources follow the pattern: `<environment>-regenesis-<component>-<region>`

**Examples:**
- `qa-regenesis-bastion-us-east-1`
- `beta-regenesis-app-us-east-1`
- `prod-regenesis-queue-us-east-1`
- `qa-regenesis-aurora-us-east-1`

### Key Terraform Outputs

```bash
# Bastion (jump host)
terraform output bastion_public_ip
terraform output bastion_eip

# Application servers
terraform output app_private_ip
terraform output queue_private_ip

# Load balancer
terraform output alb_dns

# Database
terraform output rds_cluster_endpoint
terraform output rds_cluster_reader_endpoint

# Storage & CDN
terraform output frontend_bucket
terraform output cloudfront_domain

# Container registry
terraform output ecr_api_url
terraform output ecr_queue_url

# Network
terraform output vpc_id
```

## 📞 Support

For issues or questions:
- Check the troubleshooting section above
- Review Terraform documentation: https://www.terraform.io/docs
- Check AWS documentation: https://docs.aws.amazon.com
- Review the Quick Reference section for common commands
- Contact your infrastructure team

## 📄 License

See LICENSE.txt file for details.

---

**Last Updated**: $(date)
**Terraform Version**: >= 1.0
**AWS Provider Version**: ~> 5.0
