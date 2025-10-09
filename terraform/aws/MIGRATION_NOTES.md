# Migration Notes

## Old Configuration Preserved

Your old `terraform.tfvars` has been saved as `terraform.tfvars.old` for reference.

You'll need to split these values between the two new modules:

### For Infrastructure Module (`infrastructure/terraform.tfvars`):
```hcl
region              = "eu-north-1"
app_name            = "cp-gen"
environment         = "dev"
aws_profile         = "default"
vpc_id              = "vpc-04e4448b3a2ed9fdc"
vpc_cidr            = "10.0.0.0/16"  # Update with your VPC CIDR
private_subnet_ids  = ["subnet-0d8b40723a64275a7", "subnet-0755dcb04621834fe"]
llm_api_key         = "your-key-here"
db_password         = "your-password-here"
```

### For Application Module (`application/terraform.tfvars`):
```hcl
region              = "eu-north-1"
app_name            = "cp-gen"
environment         = "dev"
aws_profile         = "default"
vpc_id              = "vpc-04e4448b3a2ed9fdc"
private_subnet_ids  = ["subnet-0d8b40723a64275a7", "subnet-0755dcb04621834fe"]
public_subnet_ids   = ["subnet-0ca84711caf88c449", "subnet-0bc9c0fdb4e82ef1e"]
llm_base_url        = "https://api.openai.com/v1"

# Get these values from infrastructure module outputs:
db_instance_identifier       = "cp-gen-db-dev"
db_security_group_id        = "sg-xxxxx"  # From infrastructure output
s3_bucket_name              = "cp-gen-documents-dev-xxxxx"  # From infrastructure output
llm_api_key_secret_name     = "cp-gen-llm-api-key-dev"
db_password_secret_name     = "cp-gen-db-password-dev"
ecr_backend_repository_name = "cp-gen/backend"
ecr_frontend_repository_name = "cp-gen/frontend"
```

## Important: Existing State

If you've already deployed infrastructure using the old configuration, you have two options:

### Option 1: Import existing resources (Recommended)
Use `terraform import` to bring existing resources into the new modules.

### Option 2: Fresh deployment
Destroy the old infrastructure and redeploy using the new module structure.
