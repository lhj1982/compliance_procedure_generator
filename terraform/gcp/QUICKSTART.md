# GCP Deployment Quick Start

This is a streamlined guide to get the Compliance Procedure system running on GCP quickly.

## Prerequisites Checklist

- [ ] GCP account with billing enabled
- [ ] GCP project created
- [ ] gcloud CLI installed
- [ ] Terraform >= 1.0 installed
- [ ] Docker installed

## Quick Deploy (15 minutes)

### 1. Authenticate and set project

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
export PROJECT_ID=$(gcloud config get-value project)
```

### 2. Build and push Docker images

```bash
cd terraform/gcp
./scripts/build_and_push.sh $PROJECT_ID latest
```

### 3. Configure Terraform

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:
- `project_id`: Your GCP project ID
- `db_password`: Strong password
- `llm_api_key`: Your LLM API key
- `frontend_image`: `gcr.io/YOUR_PROJECT_ID/compliance-frontend:latest`
- `admin_image`: `gcr.io/YOUR_PROJECT_ID/compliance-admin:latest`

### 4. Deploy infrastructure

```bash
terraform init
terraform apply -auto-approve
```

Wait 10-15 minutes for deployment.

### 5. Get load balancer IP

```bash
export LB_IP=$(terraform output -raw load_balancer_ip)
echo "Application will be available at: http://$LB_IP"
```

### 6. Initialize database

#### 6a. SSH to bastion

```bash
# Get the SSH command from terraform output
terraform output bastion_ssh_command

# Or manually:
gcloud compute ssh compliance-bastion-dev \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --project=$PROJECT_ID
```

#### 6b. Upload schema files to bastion

From your local machine:

```bash
gcloud compute scp ../../compliance_procedure_admin/schema/*.sql \
  compliance-bastion-dev:/tmp/ \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --project=$PROJECT_ID
```

#### 6c. Initialize database

On the bastion host:

```bash
# Get connection name (from terraform output)
DB_CONN=$(gcloud sql instances describe compliance-db-dev --format="value(connectionName)")

# Start Cloud SQL proxy
cloud_sql_proxy -instances=$DB_CONN=tcp:5432 &

# Connect and run schema
export PGPASSWORD='your-db-password'
for file in /tmp/*.sql; do
    psql -h 127.0.0.1 -U compliance_user -d compliance_db -f $file
done
```

### 7. Access the application

Wait 5 minutes for load balancer health checks, then:

```bash
curl http://$LB_IP/health
open http://$LB_IP
```

## Verify Deployment

Check all services are running:

```bash
# Cloud Run services
gcloud run services list --region=us-central1

# Cloud SQL
gcloud sql instances list

# Load balancer
gcloud compute forwarding-rules list
```

## Common Issues

### Load balancer returns 502
- Wait 5-10 minutes after deployment
- Check Cloud Run logs: `gcloud run services logs read compliance-frontend-dev --region=us-central1`

### Cannot SSH to bastion
```bash
# Add IAP permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=user:$(gcloud config get-value account) \
  --role=roles/iap.tunnelResourceAccessor
```

### Database connection fails
- Verify VPC connector: `gcloud compute networks vpc-access connectors list --region=us-central1`
- Check Cloud SQL is running: `gcloud sql instances describe compliance-db-dev`

## Cost Optimization Tips

**For development:**
1. Scale to zero when not in use (already configured)
2. Use db-f1-micro tier (smallest)
3. Stop bastion when not needed:
   ```bash
   gcloud compute instances stop compliance-bastion-dev --zone=us-central1-a
   ```
4. Use preemptible bastion (auto-stops within 24h)

**Estimated dev costs:** ~$35-45/month

## Cleanup

Remove all resources:

```bash
terraform destroy -auto-approve
```

## Next Steps

- Configure HTTPS with custom domain
- Set up Cloud Build for CI/CD
- Enable Cloud Armor for DDoS protection
- Configure monitoring and alerts
- Review production recommendations in README.md

## Architecture Diagram

```
Internet
   |
   v
[Load Balancer] (Public IP)
   |
   v
[Cloud Run - Frontend] (nginx + static files)
   |
   +---> [Cloud Run - Backend] (via VPC connector)
   |        |
   |        v
   |     [Cloud SQL] (private IP)
   |
   +---> [Cloud Run - Admin] (via VPC connector)
            |
            v
         [Cloud SQL] (private IP)

[Bastion Host] ---> [Cloud SQL] (via Cloud SQL Proxy)
(IAP SSH access)    (private IP)
```

## Support Resources

- Full documentation: See README.md
- GCP Console: https://console.cloud.google.com
- Cloud Run docs: https://cloud.google.com/run/docs
- Terraform GCP provider: https://registry.terraform.io/providers/hashicorp/google/latest/docs
