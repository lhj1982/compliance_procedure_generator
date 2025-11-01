# Deployment Guide - GCP Cloud Run

## Overview

This guide covers deploying the compliance procedure generator to GCP Cloud Run with a simplified architecture where the frontend serves static files and the browser calls the backend API directly.

## Prerequisites

- GCP project with billing enabled
- gcloud CLI installed and authenticated
- Terraform installed
- Docker installed (with buildx support for multi-platform builds)

## Architecture Summary

- **Frontend**: Public Cloud Run service serving static HTML/CSS/JS files
- **Backend**: Internal-only Cloud Run service (accessible from `*.run.app` domains only)
- **Security**: CORS restricts backend to GCP Cloud Run origins only

## Step-by-Step Deployment

### Step 1: Deploy Infrastructure

Deploy the base infrastructure (VPC, Cloud SQL, Secret Manager, Storage, Artifact Registry):

```bash
cd terraform/gcp/infrastructure
terraform init
terraform apply
```

**What this creates**:
- VPC network with public and private subnets
- Cloud SQL PostgreSQL database
- Secret Manager secret (you'll need to add the actual secret values)
- Cloud Storage bucket for documents
- Artifact Registry repositories for Docker images

### Step 2: Add Secrets to Secret Manager

Update the secret with your actual values:

```bash
# Create a JSON file with your secrets
cat > secrets.json <<EOF
{
  "llm_api_key": "your-actual-llm-api-key",
  "db_password": "your-actual-db-password"
}
EOF

# Upload to Secret Manager
gcloud secrets versions add cp-secrets-dev \
  --data-file=secrets.json \
  --project=YOUR_PROJECT_ID

# Clean up the local file
rm secrets.json
```

### Step 3: Build and Push Backend Image

Build the backend Docker image and push to Artifact Registry:

```bash
cd terraform/gcp
./scripts/build_and_push.sh YOUR_PROJECT_ID europe-north1
```

This builds **both** frontend and backend images, but we'll deploy backend first.

### Step 4: Update terraform.tfvars with Backend Image

Edit `terraform/gcp/cp_generator/terraform.tfvars`:

```hcl
backend_image = "europe-north1-docker.pkg.dev/YOUR_PROJECT_ID/cp-gen-backend/backend:latest"
# Leave frontend_image commented out for now
```

### Step 5: Deploy Backend Cloud Run Service

```bash
cd terraform/gcp/cp_generator
terraform init
terraform apply
```

**Important**: The first apply might fail with permission errors. If so, run `terraform apply` again - the depends_on in the backend service will ensure IAM permissions are set before the second attempt.

### Step 6: Get Backend URL

After successful deployment, get the backend URL:

```bash
terraform output backend_url
```

Example output: `https://cp-backend-dev-123456.europe-north1.run.app`

### Step 7: Update Frontend Config with Backend URL

This is the **critical step** - update the frontend JavaScript config with the backend URL:

**Option A: Manual Update**

Edit `frontend/static/config.js` and replace the placeholder:

```javascript
// Before
window.APP_CONFIG = {
    BACKEND_URL: "BACKEND_URL_PLACEHOLDER"
};

// After
window.APP_CONFIG = {
    BACKEND_URL: "https://cp-backend-dev-123456.europe-north1.run.app"
};
```

**Option B: Use sed Command**

From the `cp_generator` directory:

```bash
# Get the command from terraform output
terraform output -raw config_update_command

# Or run directly:
BACKEND_URL=$(terraform output -raw backend_url)
sed -i.bak "s|BACKEND_URL_PLACEHOLDER|$BACKEND_URL|g" ../../frontend/static/config.js
```

**Verify the change**:

```bash
cat ../../frontend/static/config.js
# Should show the actual backend URL, not BACKEND_URL_PLACEHOLDER
```

### Step 8: Build and Push Frontend Image

Now that the config is updated, rebuild the frontend image:

```bash
cd terraform/gcp
./scripts/build_and_push.sh YOUR_PROJECT_ID europe-north1
```

This will build the frontend with the updated config.js file baked into the image.

### Step 9: Update terraform.tfvars with Frontend Image

Edit `terraform/gcp/cp_generator/terraform.tfvars`:

```hcl
frontend_image = "europe-north1-docker.pkg.dev/YOUR_PROJECT_ID/cp-gen-frontend/frontend:latest"
backend_image  = "europe-north1-docker.pkg.dev/YOUR_PROJECT_ID/cp-gen-backend/backend:latest"
```

### Step 10: Deploy Frontend Cloud Run Service

```bash
cd terraform/gcp/cp_generator
terraform apply
```

### Step 11: Get Frontend URL and Test

```bash
terraform output frontend_url
```

Example output: `https://cp-frontend-dev-123456.europe-north1.run.app`

Open the URL in your browser. The application should load and be able to call the backend API.

**Check browser console** for the API base URL:
```
Constructor - API Base URL set to: https://cp-backend-dev-123456.europe-north1.run.app
```

## Verifying the Deployment

### 1. Check Frontend is Serving Files

```bash
curl https://cp-frontend-dev-123456.europe-north1.run.app/health
# Should return: healthy
```

### 2. Check Backend CORS Configuration

From your browser console (when on the frontend page):

```javascript
fetch('https://cp-backend-dev-123456.europe-north1.run.app/api/teams')
  .then(r => r.json())
  .then(d => console.log(d))
```

This should work because the request comes from a `*.run.app` origin.

### 3. Check Backend is NOT Publicly Accessible

Try accessing the backend from outside GCP (e.g., your local machine):

```bash
curl https://cp-backend-dev-123456.europe-north1.run.app/api/teams
# Should fail or return error (ingress restriction)
```

### 4. Check Logs

**Frontend logs**:
```bash
gcloud run services logs read cp-frontend-dev --region=europe-north1 --limit=20
```

**Backend logs**:
```bash
gcloud run services logs read cp-backend-dev --region=europe-north1 --limit=20
```

## Updating the Application

### Update Backend Code

1. Make changes to backend code
2. Rebuild and push image:
   ```bash
   cd terraform/gcp
   ./scripts/build_and_push.sh YOUR_PROJECT_ID europe-north1
   ```
3. Redeploy:
   ```bash
   cd cp_generator
   terraform apply
   ```

### Update Frontend Code (non-config changes)

1. Make changes to frontend HTML/CSS/JS
2. Rebuild and push image (config.js should still have correct backend URL):
   ```bash
   cd terraform/gcp
   ./scripts/build_and_push.sh YOUR_PROJECT_ID europe-north1
   ```
3. Redeploy:
   ```bash
   cd cp_generator
   terraform apply
   ```

### Update Backend URL (if backend is redeployed with new URL)

1. Get new backend URL:
   ```bash
   cd cp_generator
   terraform output backend_url
   ```
2. Update frontend config.js (see Step 7)
3. Rebuild frontend image (Step 8)
4. Redeploy frontend (Step 10)

## Troubleshooting

### Frontend can't reach backend (CORS error)

**Symptom**: Browser console shows CORS error

**Check**:
1. Backend CORS is configured to allow `*.run.app` origins (should be automatic)
2. Frontend is making requests with correct backend URL
3. Browser console shows: "Using BACKEND_URL from APP_CONFIG: https://..."

**Fix**: Verify config.js has correct backend URL and rebuild frontend image

### Backend URL in config.js is still BACKEND_URL_PLACEHOLDER

**Symptom**: Browser console shows: "No backend URL configured!"

**Check**:
```bash
# Check config.js in your source
cat frontend/static/config.js

# Check config.js in the Docker image
docker run --rm YOUR_FRONTEND_IMAGE cat /usr/share/nginx/html/static/config.js
```

**Fix**: Update config.js and rebuild frontend image (Steps 7-8)

### Backend returns 403 or ingress error

**Symptom**: Requests from browser to backend fail with 403

**Check**:
- Backend ingress setting: Should be `INGRESS_TRAFFIC_INTERNAL_ONLY`
- CORS configuration in backend server.py

**Fix**: Verify backend deployment and CORS config

### First terraform apply fails

**Symptom**: Backend Cloud Run fails to deploy with permission errors

**Fix**: This is expected on first deploy. Run `terraform apply` again - the depends_on clause ensures IAM permissions are ready on the second attempt.

## Environment Variables Reference

### Backend Environment Variables

Set in `terraform/gcp/cp_generator/cloud_run.tf`:

- `DB_HOST`: Cloud SQL private IP
- `DB_PORT`: 5432
- `DB_NAME`: Database name
- `DB_USER`: Database user
- `LLM_BASE_URL`: LLM API base URL
- `APP_SECRETS`: JSON from Secret Manager (contains llm_api_key and db_password)
- `DOCUMENTS_BUCKET`: Cloud Storage bucket name
- `NODE_ENV`: Environment (dev/staging/prod)
- `GCP_PROJECT_ID`: GCP project ID

### Frontend Environment Variables

**None** - Frontend is pure static files. Backend URL is configured in `static/config.js` at build time.

## Cost Optimization

- Both Cloud Run services scale to 0 when not in use
- Use `db-f1-micro` for Cloud SQL in development (~$7/month)
- Use preemptible bastion in development (~$3/month vs $7/month)
- Set `PRIVATE_RANGES_ONLY` egress to save on data transfer costs

Estimated monthly cost: **$17-38** for development environment.

## Security Notes

1. **Backend is NOT publicly accessible**
   - Ingress restriction blocks public internet
   - Only GCP Cloud Run services can access it

2. **CORS protection**
   - Backend only accepts requests from `*.run.app` origins
   - Prevents unauthorized domains from calling the API

3. **Secret management**
   - All secrets in Secret Manager
   - Backend service account has secretAccessor role
   - Frontend has NO access to secrets

4. **Database access**
   - Cloud SQL has private IP only
   - Only accessible via VPC connector or bastion

5. **Bastion access**
   - No external IP
   - SSH access only via IAP tunnel
   - Requires GCP IAM permissions

## Next Steps

- Set up custom domain for frontend
- Add Cloud Armor for DDoS protection
- Enable Cloud Logging and Monitoring
- Set up CI/CD pipeline for automated deployments
- Configure Cloud SQL backups and point-in-time recovery
