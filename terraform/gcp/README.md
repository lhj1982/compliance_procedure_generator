# GCP Deployment Guide for Compliance Procedure System

This guide covers deploying the Compliance Procedure system to Google Cloud Platform using Terraform.

## Architecture Overview

The deployment creates:

- **VPC Network**: Private network with public and private subnets
- **Cloud SQL**: PostgreSQL database in private subnet
- **Cloud Run Services**:
  - Frontend (public-facing with nginx reverse proxy)
  - Backend (private, accessed via VPC connector)
  - Admin (private, accessed via VPC connector)
- **Cloud Load Balancer**: External HTTP(S) load balancer
- **Bastion Host**: e2-micro instance for secure database access
- **Secret Manager**: Secure storage for sensitive data
- **VPC Connector**: Enables Cloud Run to access VPC resources

## Cost Optimization Features

- **Cloud Run**: Pay only for actual usage with scale-to-zero
- **db-f1-micro**: Smallest Cloud SQL tier (upgrade for production)
- **e2-micro bastion**: Cheapest VM type
- **Preemptible bastion**: Auto-terminated within 24h (dev only)
- **Minimal disk sizes**: 10GB for database and bastion
- **Auto-scaling**: Configured based on environment

## Prerequisites

1. **GCP Account** with billing enabled
2. **GCP Project** created
3. **gcloud CLI** installed and authenticated:
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```
4. **Terraform** >= 1.0 installed
5. **Docker** installed for building images

## Required GCP APIs

The Terraform will automatically enable these APIs:
- Compute Engine API
- Cloud SQL Admin API
- Service Networking API
- Serverless VPC Access API
- Cloud Run API
- Cloud Resource Manager API
- Identity-Aware Proxy API

## Step 1: Build and Push Docker Images

### 1.1 Configure Docker for GCR

```bash
gcloud auth configure-docker gcr.io
```

### 1.2 Set your project ID

```bash
export PROJECT_ID="your-gcp-project-id"
```

### 1.3 Build and push frontend image

```bash
cd compliance_procedure_generator

docker build -f Dockerfile.gcp -t gcr.io/$PROJECT_ID/compliance-frontend:latest .
docker push gcr.io/$PROJECT_ID/compliance-frontend:latest
```

### 1.4 Build and push backend image

The backend is included in the frontend image (nginx proxies to it).
If you want separate backend:

```bash
docker build -t gcr.io/$PROJECT_ID/compliance-backend:latest ./backend
docker push gcr.io/$PROJECT_ID/compliance-backend:latest
```

### 1.5 Build and push admin image

```bash
cd ../compliance_procedure_admin

docker build -f Dockerfile.gcp -t gcr.io/$PROJECT_ID/compliance-admin:latest .
docker push gcr.io/$PROJECT_ID/compliance-admin:latest
```

## Step 2: Configure Terraform Variables

### 2.1 Create terraform.tfvars

```bash
cd ../terraform/gcp
cp terraform.tfvars.example terraform.tfvars
```

### 2.2 Edit terraform.tfvars

```hcl
project_id  = "your-gcp-project-id"
region      = "us-central1"
environment = "dev"

db_tier     = "db-f1-micro"
db_name     = "compliance_db"
db_user     = "compliance_user"
db_password = "STRONG_PASSWORD_HERE"

vpc_cidr = "10.0.0.0/16"

frontend_image = "gcr.io/your-project-id/compliance-frontend:latest"
backend_image  = "gcr.io/your-project-id/compliance-backend:latest"
admin_image    = "gcr.io/your-project-id/compliance-admin:latest"

llm_api_key = "your-llm-api-key"
```

## Step 3: Deploy Infrastructure

### 3.1 Initialize Terraform

```bash
terraform init
```

### 3.2 Review the plan

```bash
terraform plan
```

### 3.3 Apply the configuration

```bash
terraform apply
```

This will take 10-15 minutes to:
- Create VPC and subnets
- Set up Cloud SQL instance
- Deploy Cloud Run services
- Configure load balancer
- Launch bastion host

### 3.4 Get outputs

```bash
terraform output
```

Save the `load_balancer_ip` - this is your application URL.

## Step 4: Initialize Database

### 4.1 SSH to bastion via IAP

```bash
# Copy the command from terraform output
gcloud compute ssh compliance-bastion-dev \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --project=your-project-id
```

### 4.2 Connect to Cloud SQL

On the bastion host:

```bash
# Get database connection name from terraform output
export DB_CONNECTION_NAME="your-project:us-central1:compliance-db-dev"

# Start Cloud SQL proxy
cloud_sql_proxy -instances=$DB_CONNECTION_NAME=tcp:5432 &

# Connect to database
psql -h 127.0.0.1 -U compliance_user -d compliance_db
```

### 4.3 Run schema migrations

```sql
-- Copy and paste SQL from schema files
\i /path/to/schema/001_initial_schema.sql
\i /path/to/schema/002_add_questions.sql
-- etc.
```

Or upload schema files to bastion:

```bash
# From your local machine
gcloud compute scp compliance_procedure_admin/schema/*.sql \
  compliance-bastion-dev:/tmp/ \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --project=your-project-id
```

## Step 5: Access the Application

### 5.1 Get the load balancer IP

```bash
terraform output load_balancer_ip
```

### 5.2 Access via browser

```
http://LOAD_BALANCER_IP
```

Note: It may take 5-10 minutes for the load balancer to be fully ready.

### 5.3 Health checks

```bash
curl http://LOAD_BALANCER_IP/health
```

## Architecture Details

### Network Flow

1. **User → Load Balancer → Frontend Cloud Run**
   - User accesses public IP
   - Load balancer routes to frontend
   - Frontend serves static HTML/JS

2. **Browser → Load Balancer → Frontend → Backend**
   - JavaScript in browser makes API calls to `/api/*`
   - Nginx in frontend container proxies to backend on port 9090
   - Backend connects to Cloud SQL via VPC connector

3. **Bastion → Cloud SQL**
   - Bastion in public subnet (no external IP, IAP access only)
   - Cloud SQL proxy connects to database
   - Database in private VPC peering connection

### Security

- **Cloud Run ingress**: Frontend allows all, backend/admin restricted
- **Cloud SQL**: Private IP only, no public access
- **Bastion**: No external IP, SSH via IAP only
- **Secrets**: Stored in Secret Manager
- **VPC**: Private subnet with NAT for outbound only

### Cost Estimates (Monthly - US Central1)

**Development (scale-to-zero):**
- Cloud Run: $0 (idle) - $10 (light usage)
- Cloud SQL db-f1-micro: ~$7
- Bastion e2-micro preemptible: ~$3.50
- VPC connector: ~$7
- Load balancer: ~$18
- **Total: ~$35-45/month**

**Production (always-on):**
- Cloud Run: ~$50-100 (depends on traffic)
- Cloud SQL db-g1-small: ~$25
- Bastion e2-micro: ~$7
- VPC connector: ~$14
- Load balancer: ~$18
- **Total: ~$115-165/month**

## Updating the Application

### Update container images

```bash
# Rebuild and push new images
docker build -f Dockerfile.gcp -t gcr.io/$PROJECT_ID/compliance-frontend:v2 .
docker push gcr.io/$PROJECT_ID/compliance-frontend:v2

# Update terraform.tfvars with new image tag
frontend_image = "gcr.io/your-project-id/compliance-frontend:v2"

# Apply changes
terraform apply
```

Cloud Run will automatically deploy the new revision with zero downtime.

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete:
- All Cloud Run services
- The database and all data
- The bastion host
- The VPC and networking

## Troubleshooting

### Cloud Run service not starting

Check logs:
```bash
gcloud run services logs read compliance-frontend-dev --region=us-central1
```

### Database connection issues

1. Verify VPC connector is attached
2. Check Cloud SQL private IP
3. Verify database credentials in Secret Manager
4. Check Cloud Run service account permissions

### Load balancer returns 502

- Wait 5-10 minutes after initial deployment
- Check Cloud Run health endpoint: `/health`
- Verify backend services are running

### Bastion SSH fails

```bash
# Ensure IAP is enabled
gcloud services enable iap.googleapis.com

# Add IAP tunnel user role
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member=user:YOUR_EMAIL \
  --role=roles/iap.tunnelResourceAccessor
```

## Monitoring and Logging

### View Cloud Run logs

```bash
gcloud run services logs read SERVICE_NAME --region=REGION --limit=100
```

### View Cloud SQL logs

```bash
gcloud sql operations list --instance=compliance-db-dev
```

### Set up monitoring alerts

Configure in GCP Console:
- Cloud Run → Metrics
- Cloud SQL → Monitoring
- Load Balancer → Monitoring

## Production Recommendations

1. **Enable HTTPS**: Uncomment SSL configuration in `load_balancer.tf`
2. **Use custom domain**: Configure Cloud DNS
3. **Enable Cloud Armor**: DDoS protection
4. **Set up Cloud CDN**: Cache static content
5. **Configure backups**: Automated Cloud SQL backups
6. **Use regional Cloud SQL**: High availability
7. **Implement CI/CD**: Cloud Build for automatic deployments
8. **Enable VPC Flow Logs**: Network monitoring
9. **Use Terraform Cloud**: Remote state management
10. **Set up Cloud Monitoring**: Alerts and dashboards

## Support

For issues specific to:
- **GCP**: Check GCP documentation
- **Terraform**: See Terraform GCP provider docs
- **Application**: Check application logs via Cloud Run
