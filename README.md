# Terraform AWS Regenesis

This repository contains Terraform code to provision the "regenesis" infrastructure on AWS. It supports multiple environments via `env/*.tfvars` and uses an S3 remote backend for state.

Supported environments (tfvars files are in `env/`):
- `dev`  — lightweight development
- `qa`   — quality-assurance
- `beta` — staging-like environment (used for testing apply/destroy flows)
- `prod` — production

Main resources provisioned
- VPC with public and private subnets
- NAT Gateway and routing
- Bastion EC2 instance (public)
- App EC2 instance(s) (private). Use `var.create_app2` to enable a second app instance (app2).
- ALB (forwarding to app on port 3000)
- Aurora (RDS) cluster + instance
- RDS credentials stored in AWS Secrets Manager (the code can either create a secret or read an existing one depending on `var.db_secret_name`)
- S3 bucket for frontend + CloudFront distribution (Origin Access Control)
- ECR repositories for services

NOTE: These resources will incur AWS charges. Destroy the environment when you no longer need it.

## Naming convention

Resources and tags follow the convention:

  <environment>-<service>-<component>-<region>

Example: `beta-regenesis-app-us-east-1`.

## Repository layout (high level)
- `backend.tf` - S3 backend configuration (remote state)
- `providers.tf` - provider blocks (AWS, random)
- `variables.tf` - inputs
- `locals.tf` - computed locals (environment, service, region)
- `vpc.tf` - VPC, subnets, route tables
- `compute_alb_bastion.tf` - EC2 instances, ALB, target group
- `rds_aurora.tf` - Aurora cluster and instance
- `s3_cloudfront.tf` - S3 + CloudFront settings (OAC enabled)
- `ecr.tf` - ECR repositories
- `iam.tf` - IAM roles, instance profile
- `outputs.tf` - useful outputs
- `env/` - environment variable files (dev/qa/beta/prod)

## Prerequisites
- Terraform >= 1.3
- AWS CLI configured or AWS credentials available via environment variables or profile
- A public SSH key for EC2 instances (set in the appropriate `env/*.tfvars` as `public_key`)

## Quick start (example: beta)

1. Ensure the S3 backend bucket exists (example: `terraform-state-beta-regenesis` in `us-east-1`).

2. Update `env/beta.tfvars` with your environment-specific values. Key variables to check:
   - `aws_region` (e.g. `us-east-1`)
   - `public_key` (the public key material or key name depending on how you manage keys)
   - `frontend_bucket_name` (leave empty to let Terraform generate a name)
   - `bastion_allowed_cidr` (your IP or CIDR that is allowed to SSH to the bastion)
   - `create_app2` (true/false) — determines whether a second app EC2 (`app2`) is created

3. Initialize Terraform and the backend (backend init uses your AWS credentials from the environment or profile):

```bash
cd /path/to/terraform-regenesis
terraform init \
  -backend-config="bucket=terraform-state-beta-regenesis" \
  -backend-config="key=beta/terraform.tfstate" \
  -backend-config="region=us-east-1"
```

If you do not want to initialize the remote backend (for local validation), use:

```bash
terraform init -backend=false
```

4. Create/select the workspace and plan:

```bash
terraform workspace new beta || terraform workspace select beta
terraform plan -var-file=env/beta.tfvars -out=beta_verify.tfplan
```

5. Apply the saved plan:

```bash
terraform apply -input=false -auto-approve beta_verify.tfplan
```

6. View outputs:

```bash
terraform output -json
```

## Secrets / RDS credentials

This code supports both reading an existing Secrets Manager secret (set `db_secret_name`) or creating one during apply. If you prefer full automation, set `db_secret_name` to empty and let Terraform create the secret and a generated password.

If a secret is created it will be named using the environment (for example `beta/rds-db-password`), and you can retrieve it with:

```bash
aws secretsmanager get-secret-value --secret-id beta/rds-db-password --region us-east-1
```

Be aware RDS has password character restrictions. If you manage secrets outside Terraform ensure the secret value uses a password compatible with RDS (no spaces, no '"', '/', or '@').

## SSH and RDS tunneling examples

SSH to the bastion:

```bash
ssh -i /path/to/your_private_key.pem ubuntu@<bastion_public_ip>
```

From bastion to app:

```bash
ssh ubuntu@<app_private_ip>
```

Create an SSH tunnel from your workstation to the RDS endpoint via bastion:

```bash
ssh -i /path/to/your_private_key.pem -N -L 3306:<rds_cluster_endpoint>:3306 ubuntu@<bastion_public_ip>
# then connect locally to 127.0.0.1:3306
```

## Destroy the environment

When finished, run (example for beta):

```bash
terraform destroy -var-file=env/beta.tfvars -auto-approve
```

## Notes, recommended improvements

- Consider adding a `Makefile` to simplify common commands (`init`, `plan`, `apply`, `destroy`).
- Consider managing the RDS secret within Terraform using `random_password`, `aws_secretsmanager_secret` and `aws_secretsmanager_secret_version` if you want a fully automated flow.
- The naming convention change to `<env>-<service>-<component>-<region>` was applied; if you see any resource names that don't match, tell me and I'll finish the refactor.

## Troubleshooting

- Backend init fails with a 403: the S3 backend is accessed during `terraform init` and uses the AWS credential chain; ensure the AWS credentials you have in your environment have permission to read/write the backend S3 object.
- SecretsManager data source not found: if Terraform uses a data source to read an existing secret make sure the secret exists before planning/applying, or change the configuration to let Terraform create the secret.
- RDS create fails with password invalid: update the Secrets Manager secret to a password that meets RDS constraints (no spaces, '"', '/', or '@').

---

If you'd like, I can:
- Add a `Makefile` and common targets
- Add a helper script to fetch secrets and create a temp client config
- Finish/refine the naming convention refactor across remaining files

Tell me which and I will implement it.
