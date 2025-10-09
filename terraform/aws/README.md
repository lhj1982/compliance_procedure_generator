# AWS Terraform Infrastructure

This Terraform configuration is split into two separate modules to isolate foundational resources from application deployments:

## Module Structure

### 1. Infrastructure Module (`infrastructure/`)
**Purpose**: Creates foundational resources that should persist across deployments and rarely change.

**Resources Created**:
- RDS PostgreSQL database
- S3 bucket for document storage
- AWS Secrets Manager secrets (LLM API key, DB password)
- ECR repositories (for Docker images)
- RDS security group

**When to deploy**: Once during initial setup, or when you need to modify database/storage configuration.

### 2. Application Module (`application/`)
**Purpose**: Creates application-level resources that can be updated frequently without affecting the database or storage.

**Resources Created**:
- ECS Cluster, Task Definitions, and Services
- Application Load Balancer (ALB) and Target Groups
- Security groups for ALB and ECS tasks
- IAM roles and policies
- CloudWatch log groups

**When to deploy**: Whenever you update your application code, change ECS configuration, or modify the ALB.

## Deployment Order

### Initial Setup

1. **Deploy Infrastructure Module First**:
   ```bash
   cd infrastructure/
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   terraform init
   terraform plan
   terraform apply
   
   # Save outputs for application module
   terraform output
   ```

2. **Deploy Application Module Second**:
   ```bash
   cd ../application/
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with values from infrastructure outputs
   terraform init
   terraform plan
   terraform apply
   ```

### Redeploying Application

When you need to update your application (new code, ECS config changes, etc.):

```bash
cd application/
terraform plan
terraform apply
```

This will update only the application resources without touching the database, S3, or secrets.

### Updating Infrastructure

When you need to modify database settings, add secrets, etc.:

```bash
cd infrastructure/
terraform plan
terraform apply
```

**⚠️ Warning**: Be careful when modifying infrastructure resources, especially the database, as changes may require downtime or data migration.

## Getting Infrastructure Outputs for Application Module

After deploying the infrastructure module, you need to pass certain values to the application module. Run:

```bash
cd infrastructure/
terraform output
```

Use these outputs to fill in the application module's `terraform.tfvars`:
- `db_instance_identifier` → from RDS identifier
- `db_security_group_id` → from security group output
- `s3_bucket_name` → from S3 bucket output
- Secret names → from Secrets Manager outputs
- ECR repository names → from ECR outputs

## Destroying Resources

Destroy in reverse order:

1. Destroy application first:
   ```bash
   cd application/
   terraform destroy
   ```

2. Then destroy infrastructure:
   ```bash
   cd ../infrastructure/
   terraform destroy
   ```

## Benefits of This Structure

1. **Safety**: Database and storage are protected from accidental changes during application deployments
2. **Speed**: Application deployments are faster since they don't need to check infrastructure resources
3. **Isolation**: Different teams can manage infrastructure vs application resources
4. **Cost Control**: Prevents accidental recreation of costly resources (RDS, S3)
5. **State Management**: Smaller state files are easier to manage and less prone to conflicts
