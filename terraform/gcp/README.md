# GCP Terraform Infrastructure

This Terraform configuration is split into two separate modules to isolate foundational resources from application deployments:

## Module Structure

### 1. Infrastructure Module (`infrastructure/`)
**Purpose**: Creates foundational resources that should persist across deployments and rarely change.

**Resources Created**:
- VPC Network with public and private subnets
- Cloud SQL PostgreSQL database
- Cloud Storage bucket for document storage
- Secret Manager secrets (LLM API key, DB password)
- Artifact Registry repositories (for Docker images)
- VPC Access Connector for Cloud Run
- Cloud NAT for outbound traffic
- Service Account for Cloud Run

**When to deploy**: Once during initial setup, or when you need to modify database/storage configuration.

### 2. Application Module (`cp_generator/`)
**Purpose**: Creates application-level resources that can be updated frequently without affecting the database or storage.

**Resources Created**:
- Cloud Run services (backend and frontend)
- Load Balancers (internal for backend, external for frontend)
- Network Endpoint Groups
- Health checks
- IAM bindings for service invocation

**When to deploy**: Whenever you update your application code, change Cloud Run configuration, or modify the load balancers.

## GCP vs AWS Service Mapping

| AWS Service | GCP Equivalent | Purpose |
|------------|----------------|---------|
| ECS Fargate | Cloud Run | Serverless container runtime |
| RDS PostgreSQL | Cloud SQL PostgreSQL | Managed PostgreSQL database |
| S3 | Cloud Storage | Object storage |
| ECR | Artifact Registry | Container image registry |
| Secrets Manager | Secret Manager | Secrets storage |
| VPC | VPC Network | Virtual network |
| NAT Gateway | Cloud NAT | Outbound internet access |
| ALB | Load Balancer | Application load balancing |
| IAM Roles | Service Accounts | Identity and access management |

## Prerequisites

1. **GCP Project**: Create a GCP project and note the project ID
2. **gcloud CLI**: Install and configure the gcloud CLI
   ```bash
   gcloud auth login
   gcloud auth application-default login  # Set up application default credentials for Terraform
   gcloud config set project YOUR_PROJECT_ID
   ```
3. **Enable Billing**: Ensure billing is enabled for your project
4. **Terraform**: Install Terraform >= 1.0

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

2. **Build and Push Docker Images**:
   ```bash
   # Configure Docker to use Artifact Registry
   gcloud auth configure-docker us-central1-docker.pkg.dev

   # Build and push backend image
   cd ../../backend
   docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT/compliance-procedure-gen-backend/backend:latest .
   docker push us-central1-docker.pkg.dev/YOUR_PROJECT/compliance-procedure-gen-backend/backend:latest

   # Build and push frontend image
   cd ../frontend
   docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT/compliance-procedure-gen-frontend/frontend:latest .
   docker push us-central1-docker.pkg.dev/YOUR_PROJECT/compliance-procedure-gen-frontend/frontend:latest
   ```

3. **Deploy Application Module Second**:
   ```bash
   cd ../terraform/gcp/cp_generator/
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with values from infrastructure outputs
   terraform init
   terraform plan
   terraform apply
   ```

### Redeploying Application

When you need to update your application (new code, Cloud Run config changes, etc.):

```bash
# Push new images
docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT/compliance-procedure-gen-backend/backend:latest .
docker push us-central1-docker.pkg.dev/YOUR_PROJECT/compliance-procedure-gen-backend/backend:latest

# Redeploy
cd terraform/gcp/cp_generator/
terraform apply
```

Cloud Run will automatically deploy the new images.

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
- `sql_instance_name` → Cloud SQL instance name
- `database_name` → Database name
- `storage_bucket_name` → Cloud Storage bucket name
- `secret_manager_secret_id` → Secret Manager secret ID
- `vpc_connector_name` → VPC Access Connector name
- `gen_backend_registry` → Artifact Registry for backend
- `gen_frontend_registry` → Artifact Registry for frontend
- `service_account_email` → Service account email

## Destroying Resources

Destroy in reverse order:

1. Destroy application first:
   ```bash
   cd cp_generator/
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
4. **Cost Control**: Prevents accidental recreation of costly resources (Cloud SQL, Cloud Storage)
5. **State Management**: Smaller state files are easier to manage and less prone to conflicts

## Cost Optimization

Cloud Run is serverless and scales to zero, meaning you only pay when requests are being processed. Key settings for cost optimization:

- **Min instances**: Set to 0 for development (configured in the tf files)
- **Max instances**: Set to 10 to limit max cost (can be adjusted)
- **CPU allocation**: Uses `cpu_idle = true` to only allocate CPU during request processing

Estimated costs (us-central1, dev environment):
- Cloud SQL (db-f1-micro): ~$15-20/month
- Cloud Storage: ~$0.026/GB/month + operations
- Cloud Run: Pay per use (free tier: 2M requests/month)
- Load Balancer: ~$18/month + bandwidth
- VPC Connector: ~$8.35/month

## Health Checks

Both backend and frontend services have health checks configured at multiple levels:

1. **Cloud Run Health Probes**:
   - Startup probe: Checks if container started successfully
   - Liveness probe: Checks if container is healthy and responsive

2. **Load Balancer Health Checks**:
   - Checks backend service availability
   - Automatically removes unhealthy instances from rotation

Health check configuration:
- Path: `/`
- Interval: 30 seconds
- Timeout: 5 seconds
- Healthy threshold: 2
- Unhealthy threshold: 2

## Troubleshooting

### Check Cloud Run Logs
```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=compliance-procedure-backend" --limit 50
```

### View Service Status
```bash
gcloud run services describe compliance-procedure-backend --region=us-central1
gcloud run services describe compliance-procedure-frontend --region=us-central1
```

### Test Backend Connectivity
```bash
# From within the VPC (e.g., via Cloud Shell with VPC connector)
curl http://BACKEND_SERVICE_URI/
```

### Database Connection Issues
- Ensure VPC Access Connector is properly configured
- Check that Cloud SQL is configured for private IP
- Verify service account has `cloudsql.client` role



test backend using bastion server
```
# Get identity token
TOKEN=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=https://cp-gen-backend-m2gwayie3a-lz.a.run.app)

# Test the API with authentication
curl -H "Authorization: Bearer $TOKEN" \
  https://cp-gen-backend-m2gwayie3a-lz.a.run.app/api/teams
```