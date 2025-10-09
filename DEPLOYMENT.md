# Multi-Cloud Deployment Guide

This guide covers deploying the Compliance Procedure Generator to **Google Cloud Platform (GCP)** or **Amazon Web Services (AWS)** using Terraform and containers, optimized for minimal cost.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Structure](#project-structure)
3. [Deployment to GCP](#deployment-to-gcp)
4. [Deployment to AWS](#deployment-to-aws)
5. [Cost Optimization](#cost-optimization)
6. [Local Development](#local-development)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### General Requirements

- **Docker** and **Docker Compose** installed
- **Terraform** (v1.0+) installed
- **Git** installed
- LLM API key (OpenAI or compatible API)
- Database password (secure, min 16 characters recommended)

### GCP-Specific Requirements

- GCP account with billing enabled
- `gcloud` CLI installed and authenticated
- A GCP project created
- Required APIs enabled (Terraform will handle this automatically)

### AWS-Specific Requirements

- AWS account with billing enabled
- AWS CLI installed and configured
- IAM user with appropriate permissions
- ECR, ECS, RDS, S3 access

---

## Project Structure

```
compliance_procedure_generator/
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── server.py
│   └── storage_handler.py       # Multi-cloud storage support
├── frontend/
│   ├── Dockerfile
│   └── static/
├── terraform/
│   ├── gcp/                      # GCP-specific Terraform
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── aws/                      # AWS-specific Terraform
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
├── docker-compose.yml            # Local development
└── .env.example
```

---

## Deployment to GCP

### Step 1: Authenticate with GCP

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### Step 2: Configure Terraform Variables

```bash
cd terraform/gcp
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id  = "your-gcp-project-id"
region      = "us-central1"
app_name    = "compliance-procedure-gen"
environment = "dev"
llm_base_url = "https://api.openai.com/v1"
```

Set sensitive variables as environment variables:

```bash
export TF_VAR_llm_api_key="your-openai-api-key"
export TF_VAR_db_password="your-secure-database-password"
```

### Step 3: Build and Push Docker Images

```bash
# Enable Artifact Registry API
gcloud services enable artifactregistry.googleapis.com

# Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build backend image
cd ../../backend
docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/compliance-procedure-gen-repo/backend:latest .

# Build frontend image
cd ../frontend
docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/compliance-procedure-gen-repo/frontend:latest .

# Push images
docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/compliance-procedure-gen-repo/backend:latest
docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/compliance-procedure-gen-repo/frontend:latest
```

### Step 4: Deploy Infrastructure with Terraform

```bash
cd ../terraform/gcp

# Initialize Terraform
terraform init

# Review deployment plan
terraform plan

# Deploy infrastructure
terraform apply
```

### Step 5: Access Your Application

After deployment completes, Terraform will output the URLs:

```bash
terraform output frontend_url
terraform output backend_url
```

### Step 6: Initialize Database Schema

Connect to your Cloud SQL instance and run the database migration:

```bash
# Get database connection details
terraform output database_connection_name

# Connect using Cloud SQL Proxy
gcloud sql connect YOUR_INSTANCE_NAME --user=postgres --database=compliance_admin

# Run migration scripts from compliance_procedure_admin project
\i /path/to/compliance_procedure_admin/schema/001_initial_schema.sql
\i /path/to/compliance_procedure_admin/schema/002_teams_table.sql
\i /path/to/compliance_procedure_admin/schema/003_update_procedures_table.sql
```

---

## Deployment to AWS

### Step 1: Configure AWS CLI

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and default region
```

### Step 2: Configure Terraform Variables

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
region      = "us-east-1"
app_name    = "compliance-procedure-gen"
environment = "dev"
llm_base_url = "https://api.openai.com/v1"
```

Set sensitive variables as environment variables:

```bash
export TF_VAR_llm_api_key="your-openai-api-key"
export TF_VAR_db_password="your-secure-database-password"
```

### Step 3: Deploy Infrastructure with Terraform

```bash
# Initialize Terraform
terraform init

# Review deployment plan
terraform plan

# Deploy infrastructure
terraform apply
```

**Note:** Terraform will create ECR repositories. The repository URLs will be in the outputs.

### Step 4: Build and Push Docker Images

```bash
# Get ECR login credentials
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1

aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build backend image
cd ../../backend
docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/compliance-procedure-gen/backend:latest .

# Build frontend image
cd ../frontend
docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/compliance-procedure-gen/frontend:latest .

# Push images
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/compliance-procedure-gen/backend:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/compliance-procedure-gen/frontend:latest
```

### Step 5: Update ECS Services

After pushing new images, update the ECS services to use the new images:

```bash
# Force new deployment
aws ecs update-service \
  --cluster compliance-procedure-gen-cluster \
  --service compliance-procedure-gen-backend-service \
  --force-new-deployment \
  --region $AWS_REGION

aws ecs update-service \
  --cluster compliance-procedure-gen-cluster \
  --service compliance-procedure-gen-frontend-service \
  --force-new-deployment \
  --region $AWS_REGION
```

### Step 6: Access Your Application

Get the Application Load Balancer DNS name:

```bash
terraform output alb_dns_name
terraform output frontend_url
terraform output backend_url
```

Access your application at: `http://<alb-dns-name>`

### Step 7: Initialize Database Schema

Connect to your RDS instance:

```bash
# Get database endpoint
DB_ENDPOINT=$(terraform output -raw db_endpoint)

# Connect using psql (requires PostgreSQL client installed)
psql -h $DB_ENDPOINT -U postgres -d compliance_admin

# Run migration scripts
\i /path/to/compliance_procedure_admin/schema/001_initial_schema.sql
\i /path/to/compliance_procedure_admin/schema/002_teams_table.sql
\i /path/to/compliance_procedure_admin/schema/003_update_procedures_table.sql
```

---

## Cost Optimization

### GCP Cost-Saving Features

1. **Cloud Run**: Scale-to-zero when idle (no requests = $0)
2. **Cloud SQL**: db-f1-micro tier (smallest instance)
3. **Storage**: HDD instead of SSD, lifecycle policies for 90-day deletion
4. **No multi-AZ**: Single zone deployment
5. **Minimal instances**: 0 minimum, scale up only when needed

**Estimated Monthly Cost (low traffic):**
- Cloud Run: ~$0-5 (idle most of the time)
- Cloud SQL db-f1-micro: ~$7-15
- Cloud Storage: ~$0.02/GB + operations
- **Total: ~$10-25/month**

### AWS Cost-Saving Features

1. **Fargate Spot** (optional): Use spot instances for additional savings
2. **RDS db.t3.micro**: Smallest instance class
3. **Single NAT Gateway**: Only one NAT instead of multi-AZ
4. **No Multi-AZ RDS**: Single AZ deployment
5. **Minimal task count**: 1 task per service
6. **S3 Lifecycle**: 90-day deletion policy
7. **7-day log retention**: Reduce CloudWatch costs

**Estimated Monthly Cost (low traffic):**
- ECS Fargate (2 tasks, minimal): ~$15-20
- RDS db.t3.micro: ~$15-20
- Application Load Balancer: ~$16
- NAT Gateway: ~$32
- S3 Storage: ~$0.02/GB
- **Total: ~$80-90/month**

### Additional Cost Reduction Tips

1. **Use Reserved Instances/Commitments** for production workloads
2. **Enable auto-scaling** based on metrics to scale down during low traffic
3. **Use CloudWatch/Cloud Monitoring alarms** to track unexpected costs
4. **Review and delete unused resources** regularly
5. **Consider using Cloud Run on GCP** for better cost efficiency vs. AWS ECS

---

## Local Development

For local development without cloud deployment:

```bash
# Copy environment file
cp .env.example .env

# Edit .env with local configuration
nano .env

# Start services with Docker Compose
docker-compose up --build

# Or run without Docker:
# Backend
cd backend
pip install -r requirements.txt
python server.py

# Frontend
cd frontend
npm run dev
```

**Local services:**
- Backend: http://localhost:9090
- Frontend: http://localhost:8082

---

## Troubleshooting

### GCP Issues

**Cloud Run deployment fails:**
```bash
# Check service logs
gcloud logging read "resource.type=cloud_run_revision" --limit 50 --format json
```

**Database connection issues:**
```bash
# Verify VPC connector
gcloud compute networks vpc-access connectors list --region=us-central1

# Check Cloud SQL instance status
gcloud sql instances describe YOUR_INSTANCE_NAME
```

**Image push fails:**
```bash
# Re-authenticate Docker
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### AWS Issues

**ECS tasks not starting:**
```bash
# Check ECS service events
aws ecs describe-services \
  --cluster compliance-procedure-gen-cluster \
  --services compliance-procedure-gen-backend-service

# Check task logs in CloudWatch
aws logs tail /ecs/compliance-procedure-gen/backend --follow
```

**Database connection timeout:**
- Verify security groups allow traffic from ECS tasks
- Check VPC configuration and route tables
- Ensure RDS is in private subnets with proper connectivity

**ALB returns 502/504 errors:**
- Check ECS task health in target groups
- Verify container port mappings (9090 for backend, 8082 for frontend)
- Review CloudWatch logs for application errors

### General Issues

**Out of memory errors:**
- Increase container memory in Terraform configuration
- Review application memory usage and optimize

**Slow performance:**
- Check database connection pool settings
- Review Cloud Run/ECS CPU and memory allocations
- Monitor application logs for bottlenecks

**Storage access denied:**
- Verify IAM roles/service accounts have proper permissions
- Check bucket/storage configuration
- Ensure correct environment variables (USE_GCS or USE_S3)

---

## Updating Deployments

### GCP

```bash
# Rebuild and push images
cd backend
docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/compliance-procedure-gen-repo/backend:latest .
docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/compliance-procedure-gen-repo/backend:latest

# Cloud Run will automatically deploy new image on next revision
```

### AWS

```bash
# Rebuild and push images
cd backend
docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/compliance-procedure-gen/backend:latest .
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/compliance-procedure-gen/backend:latest

# Force ECS service update
aws ecs update-service \
  --cluster compliance-procedure-gen-cluster \
  --service compliance-procedure-gen-backend-service \
  --force-new-deployment \
  --region $AWS_REGION
```

---

## Cleanup

### GCP

```bash
cd terraform/gcp
terraform destroy
```

### AWS

```bash
cd terraform/aws
terraform destroy
```

**Note:** Ensure you've backed up any important data before destroying infrastructure!

---

## Security Considerations

1. **Never commit `.env` or `terraform.tfvars` files** containing secrets
2. **Use Secret Manager/Secrets Manager** for production credentials
3. **Enable HTTPS** with Cloud Load Balancer (GCP) or ALB with ACM certificate (AWS)
4. **Restrict database access** to private networks only
5. **Use VPC/Security Groups** to limit access between services
6. **Enable audit logging** in both GCP and AWS
7. **Regularly rotate credentials** and API keys
8. **Use least-privilege IAM policies**

---

## Next Steps

1. **Set up CI/CD pipeline** with GitHub Actions or Cloud Build
2. **Add monitoring and alerting** with Cloud Monitoring/CloudWatch
3. **Configure custom domain** and SSL certificates
4. **Implement backup strategies** for databases and storage
5. **Add rate limiting** and DDoS protection
6. **Set up development/staging/production environments**

For questions or issues, please refer to the main README.md or open an issue in the repository.
