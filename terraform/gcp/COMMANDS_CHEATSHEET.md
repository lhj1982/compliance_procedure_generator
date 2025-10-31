# GCP Deployment Commands Cheatsheet

Quick reference for common commands when working with the GCP deployment.

## Initial Setup

### Authenticate with GCP
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
export PROJECT_ID=$(gcloud config get-value project)
```

### Install Terraform
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

## Building and Pushing Images

### Quick build and push (using script)
```bash
cd terraform/gcp
./scripts/build_and_push.sh $PROJECT_ID latest
```

### Manual build and push
```bash
# Configure Docker for GCR
gcloud auth configure-docker gcr.io

# Build frontend
cd compliance_procedure_generator
docker build -f Dockerfile.gcp -t gcr.io/$PROJECT_ID/compliance-frontend:latest .
docker push gcr.io/$PROJECT_ID/compliance-frontend:latest

# Build admin
cd ../compliance_procedure_admin
docker build -f Dockerfile.gcp -t gcr.io/$PROJECT_ID/compliance-admin:latest .
docker push gcr.io/$PROJECT_ID/compliance-admin:latest
```

### Tag and push new version
```bash
docker tag gcr.io/$PROJECT_ID/compliance-frontend:latest gcr.io/$PROJECT_ID/compliance-frontend:v1.2
docker push gcr.io/$PROJECT_ID/compliance-frontend:v1.2
```

## Terraform Operations

### Initialize
```bash
cd terraform/gcp
terraform init
```

### Plan (preview changes)
```bash
terraform plan
```

### Apply (deploy)
```bash
# Interactive
terraform apply

# Auto-approve
terraform apply -auto-approve

# With specific var file
terraform apply -var-file=prod.tfvars
```

### Destroy (delete all resources)
```bash
terraform destroy

# Auto-approve
terraform destroy -auto-approve
```

### Show current state
```bash
terraform show
```

### List all resources
```bash
terraform state list
```

### Get specific output
```bash
terraform output load_balancer_ip
terraform output -raw bastion_ssh_command
terraform output -json db_connection_info
```

### Format and validate
```bash
terraform fmt -recursive
terraform validate
```

## GCP Resource Management

### List Cloud Run services
```bash
gcloud run services list --region=us-central1
```

### View Cloud Run logs
```bash
gcloud run services logs read compliance-frontend-dev --region=us-central1 --limit=100
gcloud run services logs read compliance-backend-dev --region=us-central1 --limit=100
```

### Describe Cloud Run service
```bash
gcloud run services describe compliance-frontend-dev --region=us-central1
```

### Update Cloud Run service
```bash
gcloud run services update compliance-frontend-dev \
  --region=us-central1 \
  --image=gcr.io/$PROJECT_ID/compliance-frontend:v2
```

### List Cloud SQL instances
```bash
gcloud sql instances list
```

### Describe Cloud SQL instance
```bash
gcloud sql instances describe compliance-db-dev
```

### List database operations
```bash
gcloud sql operations list --instance=compliance-db-dev
```

### Get database connection name
```bash
gcloud sql instances describe compliance-db-dev --format="value(connectionName)"
```

### List compute instances (bastion)
```bash
gcloud compute instances list
```

### Start/stop bastion
```bash
# Stop (save money when not in use)
gcloud compute instances stop compliance-bastion-dev --zone=us-central1-a

# Start
gcloud compute instances start compliance-bastion-dev --zone=us-central1-a
```

### List load balancers
```bash
gcloud compute forwarding-rules list
gcloud compute backend-services list
```

### List VPC networks
```bash
gcloud compute networks list
gcloud compute networks subnets list --network=compliance-vpc-dev
```

### List firewall rules
```bash
gcloud compute firewall-rules list --filter="network:compliance-vpc-dev"
```

## Bastion Access

### SSH via IAP
```bash
gcloud compute ssh compliance-bastion-dev \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --project=$PROJECT_ID
```

### Upload files to bastion
```bash
# Upload schema files
gcloud compute scp compliance_procedure_admin/schema/*.sql \
  compliance-bastion-dev:/tmp/ \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --project=$PROJECT_ID

# Upload single file
gcloud compute scp local-file.txt \
  compliance-bastion-dev:/tmp/ \
  --zone=us-central1-a \
  --tunnel-through-iap
```

### Download files from bastion
```bash
gcloud compute scp compliance-bastion-dev:/tmp/backup.sql . \
  --zone=us-central1-a \
  --tunnel-through-iap
```

### Port forwarding from bastion
```bash
# Forward local port 5432 to Cloud SQL via bastion
gcloud compute start-iap-tunnel compliance-bastion-dev 5432 \
  --local-host-port=localhost:5432 \
  --zone=us-central1-a
```

## Database Operations

### Connect to database via bastion
```bash
# On bastion host
export DB_CONN=$(gcloud sql instances describe compliance-db-dev --format="value(connectionName)")
cloud_sql_proxy -instances=$DB_CONN=tcp:5432 &

export PGPASSWORD='your-password'
psql -h 127.0.0.1 -U compliance_user -d compliance_db
```

### Run SQL file
```bash
psql -h 127.0.0.1 -U compliance_user -d compliance_db -f /tmp/schema.sql
```

### Database backup
```bash
# Create on-demand backup
gcloud sql backups create --instance=compliance-db-dev

# List backups
gcloud sql backups list --instance=compliance-db-dev

# Restore from backup
gcloud sql backups restore BACKUP_ID --backup-instance=compliance-db-dev --instance=compliance-db-dev
```

### Export database
```bash
# Export to Cloud Storage
gcloud sql export sql compliance-db-dev gs://YOUR_BUCKET/backup.sql \
  --database=compliance_db

# Import from Cloud Storage
gcloud sql import sql compliance-db-dev gs://YOUR_BUCKET/backup.sql \
  --database=compliance_db
```

## Secret Manager

### List secrets
```bash
gcloud secrets list --filter="name:compliance"
```

### View secret value
```bash
gcloud secrets versions access latest --secret=compliance-db-password-dev
gcloud secrets versions access latest --secret=compliance-llm-api-key-dev
```

### Update secret
```bash
echo -n "new-password" | gcloud secrets versions add compliance-db-password-dev --data-file=-
```

## Monitoring and Debugging

### View Cloud Run metrics
```bash
# Request count
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count"'

# CPU utilization
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/cpu/utilizations"'
```

### Tail Cloud Run logs
```bash
gcloud run services logs tail compliance-frontend-dev --region=us-central1
```

### Check service health
```bash
# Get load balancer IP
LB_IP=$(terraform output -raw load_balancer_ip)

# Health check
curl http://$LB_IP/health

# Test API
curl http://$LB_IP/api/teams
```

### Debug Cloud Run service
```bash
# Get service URL
gcloud run services describe compliance-frontend-dev \
  --region=us-central1 \
  --format="value(status.url)"

# Test directly (bypasses load balancer)
curl $(gcloud run services describe compliance-frontend-dev --region=us-central1 --format="value(status.url)")/health
```

## Cost Management

### View current month costs
```bash
gcloud billing accounts list
export BILLING_ACCOUNT_ID="YOUR_BILLING_ACCOUNT_ID"

gcloud billing projects describe $PROJECT_ID
```

### Set budget alerts
```bash
# Via Console: Billing → Budgets & alerts
# Or use Terraform google_billing_budget resource
```

### Estimate costs
```bash
# Use Google Cloud Pricing Calculator
# https://cloud.google.com/products/calculator
```

### Stop all Cloud Run services (save money)
```bash
# Scale to 0 instances
gcloud run services update compliance-frontend-dev --region=us-central1 --min-instances=0
gcloud run services update compliance-backend-dev --region=us-central1 --min-instances=0
gcloud run services update compliance-admin-dev --region=us-central1 --min-instances=0
```

## IAM and Permissions

### Add IAP tunnel access
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=user:YOUR_EMAIL \
  --role=roles/iap.tunnelResourceAccessor
```

### List service accounts
```bash
gcloud iam service-accounts list
```

### View service account permissions
```bash
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:compliance-frontend-dev@*"
```

## Quick Troubleshooting

### Cloud Run service won't start
```bash
# Check logs
gcloud run services logs read SERVICE_NAME --region=us-central1 --limit=50

# Check image exists
gcloud container images list --repository=gcr.io/$PROJECT_ID

# Describe service
gcloud run services describe SERVICE_NAME --region=us-central1
```

### Database connection fails
```bash
# Check VPC connector
gcloud compute networks vpc-access connectors list --region=us-central1

# Test from bastion
# SSH to bastion, then:
cloud_sql_proxy -instances=$DB_CONN=tcp:5432 &
psql -h 127.0.0.1 -U compliance_user -d compliance_db
```

### Load balancer returns 502
```bash
# Check backend health
gcloud compute backend-services get-health compliance-frontend-backend-dev --global

# Wait a few minutes for health checks
sleep 300

# Try again
curl http://$LB_IP/health
```

### Terraform state issues
```bash
# Refresh state
terraform refresh

# Import existing resource
terraform import google_compute_instance.bastion projects/$PROJECT_ID/zones/us-central1-a/instances/compliance-bastion-dev

# Remove resource from state (doesn't delete actual resource)
terraform state rm google_compute_instance.bastion
```

## Cleanup Commands

### Delete specific resources
```bash
# Delete Cloud Run service
gcloud run services delete compliance-frontend-dev --region=us-central1

# Delete Cloud SQL instance
gcloud sql instances delete compliance-db-dev

# Delete bastion
gcloud compute instances delete compliance-bastion-dev --zone=us-central1-a

# Delete VPC
gcloud compute networks delete compliance-vpc-dev
```

### Full cleanup
```bash
terraform destroy -auto-approve
```

## Useful Aliases

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# GCP
alias gcl='gcloud'
alias gcr='gcloud run'
alias gce='gcloud compute'
alias gcs='gcloud sql'

# Terraform
alias tf='terraform'
alias tfa='terraform apply'
alias tfp='terraform plan'
alias tfd='terraform destroy'
alias tfo='terraform output'

# Project specific
alias cpgcp='cd ~/projects/compliance_procedure/terraform/gcp'
alias cplogs='gcloud run services logs read compliance-frontend-dev --region=us-central1 --limit=100'
alias cpssh='gcloud compute ssh compliance-bastion-dev --zone=us-central1-a --tunnel-through-iap'
```

## Emergency Commands

### Rollback Cloud Run service
```bash
# List revisions
gcloud run revisions list --service=compliance-frontend-dev --region=us-central1

# Route traffic to previous revision
gcloud run services update-traffic compliance-frontend-dev \
  --region=us-central1 \
  --to-revisions=REVISION_NAME=100
```

### Force restart Cloud Run service
```bash
gcloud run services update compliance-frontend-dev \
  --region=us-central1 \
  --update-env-vars=RESTART_TIMESTAMP=$(date +%s)
```

### Restore database from backup
```bash
# List backups
gcloud sql backups list --instance=compliance-db-dev

# Restore
gcloud sql backups restore BACKUP_ID \
  --backup-instance=compliance-db-dev \
  --instance=compliance-db-dev
```
