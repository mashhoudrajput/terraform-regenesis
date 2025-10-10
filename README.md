# Terraform AWS Regenesis (compatible with Terraform >= 1.13.3)

This repository contains Terraform code to provision a betaelopment environment for the "regenesis" application on AWS.

Main resources provisioned
- VPC with public and private subnets
- NAT Gateway and routing
- Bastion EC2 instance (public)
- App EC2 instance (private)
- ALB (forwarding to app on port 3000)
- Aurora (RDS) cluster + instance
- RDS credentials stored in AWS Secrets Manager (created when not provided)
- S3 bucket for frontend + CloudFront distribution (Origin Access Control)
- Two ECR repositories (`beta-regenesis-api`, `beta-regenesis-queue`)

NOTE: These resources will incur AWS charges. Destroy the environment when you no longer need it.

## Repository layout (high level)
- `backend.tf` - S3 backend configuration (remote state)
- `providers.tf` - provider blocks (AWS, random)
- `variables.tf` - inputs
- `locals.tf` - computed locals
- `vpc.tf` - VPC, subnets, route tables
- `compute_alb_bastion.tf` - EC2 instances, ALB, target group
- `rds_aurora.tf` - Aurora cluster and instance
- `s3_cloudfront.tf` - S3 + CloudFront settings (OAC enabled)
- `ecr.tf` - ECR repositories
- `iam.tf` - IAM roles, instance profile
- `outputs.tf` - useful outputs
- `env/` - environment variable files (beta/staging/prod)

## Prerequisites
- Terraform >= 1.3 (this workspace used v1.13.3 during betaelopment)
- AWS CLI configured or AWS credentials available via environment variables
- A public SSH key for EC2 instances (set in `env/beta.tfvars` as `public_key`)

## Quick start (beta)

1. Ensure the S3 backend bucket exists (example used: `terraform-state-mashhoud` in `us-east-1`).

2. Update `env/beta.tfvars` with your environment-specific values. Key variables to check:
   - `aws_region` (e.g. `us-east-1`)
   - `public_key` (the public key material or key name depending on how you manage keys)
   - `frontend_bucket_name` (leave empty to use a generated name)
   - `bastion_allowed_cidr` (your IP or CIDR that is allowed to SSH to the bastion)

3. Initialize Terraform and the backend:

```bash
cd /path/to/terraform_aws_regenesis
terraform init \
  -backend-config="bucket=terraform-state-beta-regenesis" \
  -backend-config="key=beta/terraform.tfstate" \
  -backend-config="region=us-east-1"

```

4. Create/select the workspace and plan:

```bash
terraform workspace new beta || terraform workspace select beta
terraform plan -var-file=env/beta.tfvars -out=beta_verify.tfplan
```

5. Apply the saved plan non-interactively:

```bash
terraform apply -input=false -auto-approve beta_verify.tfplan
```

6. View outputs:

```bash
terraform output -json
```

## Retrieving RDS credentials (Secrets Manager)

If the `db_secret_name` variable wasn't provided, Terraform will create a Secrets Manager secret (example in beta: `beta/rds-db-password`). The secret contains the DB credentials and a generated password.

Retrieve it using the AWS CLI (you must have permission to read the secret):

```bash
aws secretsmanager get-secret-value --secret-id beta/rds-db-password --region us-east-1
```

The `secret_string` typically contains JSON with the username/password. Handle it carefully and do not commit secret values into source control.

## SSH and RDS tunneling

- SSH to the bastion (replace the key path and IP):

```bash
ssh -i /path/to/your_private_key.pem ubuntu@<bastion_public_ip>
```

- From bastion to app:

```bash
ssh ubuntu@<app_private_ip>
```

- Create an SSH tunnel from your workstation to the RDS endpoint via bastion (forward local 3306 to RDS):

```bash
ssh -i /path/to/your_private_key.pem -N -L 3306:<rds_cluster_endpoint>:3306 ubuntu@<bastion_public_ip>
# then connect locally to 127.0.0.1:3306
```

## Verification checks performed
- Confirmed security groups allow:
  - SSH from your IP to bastion (bastion_sg allows tcp/22 from 0.0.0.0/0 or the CIDR you configured)
  - SSH from bastion_sg to app_sg (app_sg has a rule allowing tcp/22 from the bastion SG)
  - MySQL (tcp/3306) from bastion_sg and app_sg to rds_sg (rds_sg ingress includes both SGs)
- Confirmed `data.aws_secretsmanager_secret_version.db_secret[0]` exists in state with an `AWSCURRENT` version for the RDS secret.

## Destroy the environment

When finished, run:

```bash
terraform destroy -var-file=env/beta.tfvars -auto-approve
```

## Optional improvements (suggested)
- Add a `Makefile` to simplify common commands (`init`, `plan`, `apply`, `destroy`).
- Add a small helper script that retrieves the DB secret and writes a temporary `.my.cnf` for local testing (be careful with secrets).

## Troubleshooting
- SSH fails: verify your private key matches the public key configured, check the AMI username (`ubuntu` vs `ec2-user`), and check instance system logs.
- DB connection fails: ensure the SSH tunnel is up and you are connecting to `127.0.0.1:3306` (not the public endpoint) when the tunnel is active; verify secret credentials.

---

If you want, I can add a `Makefile`, a small helper script to fetch the secret, or run additional automated checks (connectivity tests) — tell me which and I will implement it.
