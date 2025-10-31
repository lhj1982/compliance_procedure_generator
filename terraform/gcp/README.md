# GCP Terraform Deployment for Compliance Procedure System

Complete infrastructure-as-code deployment for the Compliance Procedure system on Google Cloud Platform using Terraform. This deployment provides a production-ready, cost-optimized, and secure architecture.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Quick Start (15 minutes)](#quick-start-15-minutes)
- [Detailed Deployment Guide](#detailed-deployment-guide)
- [File Structure](#file-structure)
- [Cost Optimization](#cost-optimization)
- [Common Operations](#common-operations)
- [Troubleshooting](#troubleshooting)
- [Production Recommendations](#production-recommendations)

---

## Architecture Overview

### Components

- **VPC Network**: Private network with public and private subnets
- **Cloud SQL**: PostgreSQL database in private VPC peering
- **Cloud Run Services**:
  - Frontend (nginx reverse proxy + static files)
  - Backend (Node.js API for generator)
  - Admin (Node.js API for admin portal)
- **Cloud Load Balancer**: Global HTTP(S) load balancer
- **Bastion Host**: e2-micro instance with IAP access for database management
- **Secret Manager**: Encrypted storage for sensitive data
- **VPC Connector**: Enables Cloud Run to access VPC resources

### Network Architecture

```
Internet
   ↓
[Cloud Load Balancer] (Public IP: XXX.XXX.XXX.XXX)
   ↓
[VPC Network 10.0.0.0/16]
   ├─ Public Subnet (10.0.1.0/24)
   │  └─ Bastion (e2-micro, IAP SSH access)
   │
   ├─ Private Subnet (10.0.2.0/24)
   │  ├─ Cloud Run Frontend (nginx + UI)
   │  ├─ Cloud Run Backend (API)
   │  └─ Cloud Run Admin (API)
   │     ↓ (via VPC Connector)
   │
   └─ VPC Peering
      └─ Cloud SQL PostgreSQL (private IP only)
```

### Request Flow

1. **User → Frontend**: Browser requests static HTML/JS
2. **Browser → Backend**: JavaScript makes `/api/*` calls
3. **Nginx Proxy**: Frontend nginx proxies `/api/*` to backend Cloud Run
4. **Backend → Database**: Backend connects to Cloud SQL via VPC connector
5. **Bastion → Database**: Secure SSH via IAP + Cloud SQL proxy

---

## Quick Start (15 minutes)

### Prerequisites

- [ ] GCP account with billing enabled
- [ ] GCP project created
- [ ] `gcloud` CLI installed
- [ ] Terraform >= 1.0 installed
- [ ] Docker installed

### Deployment Steps

#### 1. Authenticate with GCP

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
export PROJECT_ID=$(gcloud config get-value project)
```

#### 2. Build and Push Docker Images

```bash
cd terraform/gcp
./scripts/build_and_push.sh $PROJECT_ID latest
```

Or manually:

```bash
# Configure Docker for GCR
gcloud auth configure-docker gcr.io

# Build frontend
cd ../../  # Go to compliance_procedure_generator root
docker build -f Dockerfile.gcp -t gcr.io/$PROJECT_ID/compliance-frontend:latest .
docker push gcr.io/$PROJECT_ID/compliance-frontend:latest

# Build admin
cd ../compliance_procedure_admin
docker build -f Dockerfile.gcp -t gcr.io/$PROJECT_ID/compliance-admin:latest .
docker push gcr.io/$PROJECT_ID/compliance-admin:latest
```

#### 3. Configure Terraform

```bash
cd ../compliance_procedure_generator/terraform/gcp
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id  = "your-gcp-project-id"
region      = "us-central1"
environment = "dev"

db_tier     = "db-f1-micro"
db_name     = "compliance_db"
db_user     = "compliance_user"
db_password = "CHANGE_ME_STRONG_PASSWORD"

vpc_cidr = "10.0.0.0/16"

frontend_image = "gcr.io/your-project-id/compliance-frontend:latest"
backend_image  = "gcr.io/your-project-id/compliance-backend:latest"
admin_image    = "gcr.io/your-project-id/compliance-admin:latest"

llm_api_key = "your-llm-api-key"
```

#### 4. Deploy Infrastructure

```bash
terraform init
terraform apply -auto-approve
```

Wait 10-15 minutes for deployment.

#### 5. Get Load Balancer IP

```bash
export LB_IP=$(terraform output -raw load_balancer_ip)
echo "Application URL: http://$LB_IP"
```

#### 6. Initialize Database

Upload schema files to bastion:

```bash
gcloud compute scp ../../compliance_procedure_admin/schema/*.sql \
  compliance-bastion-dev:/tmp/ \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --project=$PROJECT_ID
```

SSH to bastion:

```bash
gcloud compute ssh compliance-bastion-dev \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --project=$PROJECT_ID
```

On the bastion host:

```bash
# Get database connection name
DB_CONN=$(gcloud sql instances describe compliance-db-dev --format="value(connectionName)")

# Start Cloud SQL proxy
cloud_sql_proxy -instances=$DB_CONN=tcp:5432 &

# Run schema migrations
export PGPASSWORD='your-db-password'
for file in /tmp/*.sql; do
    psql -h 127.0.0.1 -U compliance_user -d compliance_db -f $file
done
```

#### 7. Access Application

Wait 5 minutes for health checks:

```bash
curl http://$LB_IP/health
open http://$LB_IP
```

---

## Detailed Deployment Guide

### File Structure

```
terraform/gcp/
├── main.tf                          # Root orchestration
├── variables.tf                     # Root variables
├── outputs.tf                       # Root outputs
├── terraform.tfvars.example         # Example config
├── .gitignore                       # Git ignore
│
├── infrastructure/                  # Infrastructure module
│   ├── main.tf                      # Provider & APIs
│   ├── variables.tf                 # Variables
│   ├── outputs.tf                   # Outputs
│   ├── vpc.tf                       # VPC, subnets, NAT, firewalls
│   └── database.tf                  # Cloud SQL PostgreSQL
│
├── cp_generator/                    # Application module
│   ├── main.tf                      # Provider config
│   ├── variables.tf                 # Variables
│   ├── outputs.tf                   # Outputs
│   ├── cloud_run.tf                 # Cloud Run services
│   ├── load_balancer.tf             # Load balancer
│   ├── secrets.tf                   # Secret Manager
│   └── bastion.tf                   # Bastion host
│
├── scripts/
│   ├── build_and_push.sh           # Build Docker images
│   └── init_db.sh                   # Init database
│
├── README.md                        # This file
└── AWS_VS_GCP.md                    # AWS comparison
```

### Required GCP APIs

Automatically enabled by Terraform:
- Compute Engine API
- Cloud SQL Admin API
- Service Networking API
- Serverless VPC Access API
- Cloud Run API
- Cloud Resource Manager API
- Identity-Aware Proxy API
- Secret Manager API

---

## Cost Optimization

### Cost Breakdown

#### Development Environment (~$35-45/month)
| Service | Cost | Optimization |
|---------|------|--------------|
| Cloud Run | $0-10 | Scale-to-zero when idle |
| Cloud SQL (db-f1-micro) | $7 | Smallest tier |
| Load Balancer | $18 | Standard cost |
| VPC Connector | $7 | f1-micro instances |
| Cloud NAT | $3 | Minimal usage |
| Bastion (e2-micro preemptible) | $3.50 | Auto-stops within 24h |

#### Production Environment (~$115-165/month)
| Service | Cost | Optimization |
|---------|------|--------------|
| Cloud Run | $50-100 | Min 1 instance, scales up |
| Cloud SQL (db-g1-small) | $25 | Higher tier for prod |
| Load Balancer | $18 | Standard cost |
| VPC Connector | $14 | More capacity |
| Cloud NAT | $10 | More traffic |
| Bastion (e2-micro) | $7 | Always-on |

### Cost Optimization Tips

**Development:**
1. Cloud Run automatically scales to zero when idle
2. Stop bastion when not needed:
   ```bash
   gcloud compute instances stop compliance-bastion-dev --zone=us-central1-a
   ```
3. Use preemptible bastion (already configured)
4. Use smallest db-f1-micro tier

**Comparison with AWS:**
- Dev: ~60% cheaper ($38-48 vs $97-112)
- Prod: ~30% cheaper ($124-174 vs $185-235)

See [AWS_VS_GCP.md](AWS_VS_GCP.md) for detailed comparison.

---

## Common Operations

### Terraform Commands

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy all resources
terraform destroy

# Show outputs
terraform output
terraform output -raw load_balancer_ip

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate
```

### Docker Image Management

```bash
# Build and push new version
./scripts/build_and_push.sh $PROJECT_ID v1.2

# Update terraform.tfvars with new tag
# Then apply changes
terraform apply
```

Cloud Run automatically deploys new revisions with zero downtime.

### Database Operations

```bash
# SSH to bastion
gcloud compute ssh compliance-bastion-dev \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --project=$PROJECT_ID

# On bastion: Connect to database
DB_CONN=$(gcloud sql instances describe compliance-db-dev --format="value(connectionName)")
cloud_sql_proxy -instances=$DB_CONN=tcp:5432 &
export PGPASSWORD='your-password'
psql -h 127.0.0.1 -U compliance_user -d compliance_db

# Create backup
gcloud sql backups create --instance=compliance-db-dev

# List backups
gcloud sql backups list --instance=compliance-db-dev

# Restore from backup
gcloud sql backups restore BACKUP_ID \
  --backup-instance=compliance-db-dev \
  --instance=compliance-db-dev
```

### Monitoring & Logs

```bash
# View Cloud Run logs
gcloud run services logs read compliance-frontend-dev --region=us-central1 --limit=100

# Tail logs
gcloud run services logs tail compliance-frontend-dev --region=us-central1

# List Cloud Run services
gcloud run services list --region=us-central1

# Describe service
gcloud run services describe compliance-frontend-dev --region=us-central1

# View Cloud SQL operations
gcloud sql operations list --instance=compliance-db-dev

# Check health
curl http://LOAD_BALANCER_IP/health
```

### Service Management

```bash
# List all services
gcloud run services list --region=us-central1
gcloud sql instances list
gcloud compute instances list
gcloud compute forwarding-rules list

# Update Cloud Run service
gcloud run services update compliance-frontend-dev \
  --region=us-central1 \
  --image=gcr.io/$PROJECT_ID/compliance-frontend:v2

# Scale to zero (save money)
gcloud run services update compliance-frontend-dev \
  --region=us-central1 \
  --min-instances=0
```

---

## Troubleshooting

### Load Balancer Returns 502

**Symptoms:** HTTP 502 Bad Gateway

**Solutions:**
1. Wait 5-10 minutes after initial deployment for health checks
2. Check Cloud Run service is running:
   ```bash
   gcloud run services list --region=us-central1
   ```
3. Check Cloud Run logs:
   ```bash
   gcloud run services logs read compliance-frontend-dev --region=us-central1
   ```
4. Verify health endpoint:
   ```bash
   # Get Cloud Run URL
   URL=$(gcloud run services describe compliance-frontend-dev --region=us-central1 --format="value(status.url)")
   curl $URL/health
   ```
5. Check backend health:
   ```bash
   gcloud compute backend-services get-health compliance-frontend-backend-dev --global
   ```

### Cloud Run Service Won't Start

**Symptoms:** Service status shows errors

**Solutions:**
1. Check logs for errors:
   ```bash
   gcloud run services logs read SERVICE_NAME --region=us-central1 --limit=50
   ```
2. Verify image exists:
   ```bash
   gcloud container images list --repository=gcr.io/$PROJECT_ID
   ```
3. Check environment variables and secrets:
   ```bash
   gcloud run services describe SERVICE_NAME --region=us-central1
   ```
4. Verify service account permissions:
   ```bash
   gcloud projects get-iam-policy $PROJECT_ID
   ```

### Database Connection Fails

**Symptoms:** Backend cannot connect to Cloud SQL

**Solutions:**
1. Verify VPC connector is attached:
   ```bash
   gcloud compute networks vpc-access connectors list --region=us-central1
   ```
2. Check Cloud SQL is running:
   ```bash
   gcloud sql instances describe compliance-db-dev
   ```
3. Test from bastion:
   ```bash
   # SSH to bastion
   gcloud compute ssh compliance-bastion-dev --zone=us-central1-a --tunnel-through-iap

   # Test connection
   cloud_sql_proxy -instances=$DB_CONN=tcp:5432 &
   psql -h 127.0.0.1 -U compliance_user -d compliance_db
   ```
4. Verify database credentials in Secret Manager:
   ```bash
   gcloud secrets versions access latest --secret=compliance-db-password-dev
   ```

### Cannot SSH to Bastion

**Symptoms:** IAP tunnel fails

**Solutions:**
1. Enable IAP API:
   ```bash
   gcloud services enable iap.googleapis.com
   ```
2. Add IAP permissions:
   ```bash
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member=user:YOUR_EMAIL \
     --role=roles/iap.tunnelResourceAccessor
   ```
3. Verify bastion is running:
   ```bash
   gcloud compute instances list
   ```
4. Check firewall rules:
   ```bash
   gcloud compute firewall-rules list --filter="name:bastion"
   ```

### Terraform State Issues

**Solutions:**
```bash
# Refresh state
terraform refresh

# Import existing resource
terraform import google_compute_instance.bastion \
  projects/$PROJECT_ID/zones/us-central1-a/instances/compliance-bastion-dev

# Remove resource from state (doesn't delete actual resource)
terraform state rm google_compute_instance.bastion
```

---

## Production Recommendations

### Security Enhancements

1. **Enable HTTPS**: Uncomment SSL configuration in `cp_generator/load_balancer.tf`
   ```hcl
   resource "google_compute_managed_ssl_certificate" "default" {
     managed {
       domains = ["your-domain.com"]
     }
   }
   ```

2. **Configure Cloud Armor**: Add DDoS protection
   ```bash
   gcloud compute security-policies create compliance-policy \
     --description "DDoS protection for compliance app"
   ```

3. **Restrict bastion access**: Add specific IP allowlist
4. **Enable VPC Flow Logs**: Network monitoring
5. **Set up Cloud Audit Logs**: Track admin activities

### High Availability

1. **Regional Cloud SQL**: Enable high availability
   ```hcl
   availability_type = "REGIONAL"
   ```

2. **Multi-zone deployment**: Spread resources across zones
3. **Automated backups**: Already enabled, verify retention
4. **Point-in-time recovery**: Enable for production
   ```hcl
   point_in_time_recovery_enabled = true
   ```

### Performance Optimization

1. **Enable Cloud CDN**: Cache static content
2. **Increase Cloud Run resources**: More CPU/memory for prod
3. **Connection pooling**: Configure for Cloud SQL
4. **Database indexes**: Optimize query performance

### Operational Excellence

1. **CI/CD Pipeline**: Set up Cloud Build
   ```yaml
   steps:
     - name: 'gcr.io/cloud-builders/docker'
       args: ['build', '-t', 'gcr.io/$PROJECT_ID/compliance-frontend:$SHORT_SHA', '.']
     - name: 'gcr.io/cloud-builders/docker'
       args: ['push', 'gcr.io/$PROJECT_ID/compliance-frontend:$SHORT_SHA']
   ```

2. **Monitoring Alerts**: Configure Cloud Monitoring
   - Cloud Run error rate
   - Database CPU utilization
   - Load balancer latency

3. **Log Aggregation**: Export logs to BigQuery or Cloud Storage
4. **Terraform Remote State**: Use Cloud Storage backend
   ```hcl
   terraform {
     backend "gcs" {
       bucket = "your-terraform-state-bucket"
       prefix = "compliance-procedure"
     }
   }
   ```

5. **Infrastructure Testing**: Use Terratest or similar

### Cost Management

1. **Set budget alerts**:
   ```bash
   # Via Console: Billing → Budgets & alerts
   ```
2. **Right-size resources**: Monitor and adjust based on usage
3. **Committed use discounts**: For production workloads
4. **Scheduled scaling**: Scale down during off-hours

---

## Cleanup

To remove all resources and stop billing:

```bash
terraform destroy -auto-approve
```

**Warning:** This permanently deletes:
- All Cloud Run services
- The database and all data
- The bastion host
- VPC and networking resources
- Load balancer and static IP

---

## Support & Resources

### Documentation
- This README - Complete deployment guide
- [AWS_VS_GCP.md](AWS_VS_GCP.md) - Detailed comparison with AWS
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Migration instructions

### External Resources
- [GCP Documentation](https://cloud.google.com/docs)
- [Cloud Run Docs](https://cloud.google.com/run/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)

### Common Commands Quick Reference

```bash
# Authenticate
gcloud auth login
gcloud config set project PROJECT_ID

# Deploy
terraform init
terraform apply -auto-approve

# Monitor
gcloud run services logs read SERVICE_NAME --region=REGION
terraform output load_balancer_ip

# Update
./scripts/build_and_push.sh PROJECT_ID v2
terraform apply

# Cleanup
terraform destroy -auto-approve
```

---

## Summary

You now have a complete, production-ready GCP deployment featuring:

✅ **Cost-optimized** (~60% cheaper than AWS for dev)
✅ **Secure** (private DB, IAP, Secret Manager)
✅ **Scalable** (Cloud Run auto-scaling, scale-to-zero)
✅ **High availability** (load balancer, health checks)
✅ **Infrastructure as Code** (full Terraform automation)
✅ **Simple operations** (automated scripts, clear docs)

**Deployment time:** 15 minutes
**Dev monthly cost:** ~$35-45
**Prod monthly cost:** ~$115-165

Ready to deploy! 🚀
