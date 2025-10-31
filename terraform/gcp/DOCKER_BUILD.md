# Docker Build and Deployment Guide for GCP

## Overview

The compliance procedure generator uses **separate Docker images** for frontend and backend components:

- **Generator Backend**: Python-based API service
- **Generator Frontend**: Nginx-based static file server with reverse proxy to backend

## Image Architecture

### Separate Images Approach

We build and deploy frontend and backend as **separate images** rather than a combined image. This provides:

- **Better separation of concerns**: Frontend and backend scale independently
- **Smaller image sizes**: Each image only contains what it needs
- **Easier updates**: Can update frontend or backend without rebuilding both
- **GCP best practices**: Follows Cloud Run microservices pattern

## Dockerfiles

### Generator Backend
- **Location**: `compliance_procedure_generator/backend/Dockerfile.gcp`
- **Base Image**: `python:3.11-slim`
- **Port**: 9090
- **Purpose**: Runs the Python Flask/FastAPI backend server

### Generator Frontend
- **Location**: `compliance_procedure_generator/frontend/Dockerfile.gcp`
- **Base Image**: `nginx:alpine`
- **Port**: 8080 (Cloud Run compatible)
- **Purpose**: Serves static files and proxies `/api/*` requests to backend

## Artifact Registry Repositories

The infrastructure module creates these repositories:

1. `{app_name}-gen-backend` - Generator backend images
2. `{app_name}-gen-frontend` - Generator frontend images
3. `{app_name}-admin-backend` - Admin backend images (future)
4. `{app_name}-admin-frontend` - Admin frontend images (future)

## Building and Pushing Images

### Using the Build Script

```bash
cd terraform/gcp
./scripts/build_and_push.sh <project-id> <region> [tag] [app-name]
```

**Example**:
```bash
./scripts/build_and_push.sh my-gcp-project us-central1 latest compliance-procedure
```

This will:
1. Configure Docker for Artifact Registry authentication
2. Build generator backend from `backend/Dockerfile.gcp` (using `--platform linux/amd64`)
3. Push to `us-central1-docker.pkg.dev/my-gcp-project/compliance-procedure-gen-backend/backend:latest`
4. Build generator frontend from `frontend/Dockerfile.gcp` (using `--platform linux/amd64`)
5. Push to `us-central1-docker.pkg.dev/my-gcp-project/compliance-procedure-gen-frontend/frontend:latest`

**Note**: The build script uses `docker buildx build --platform linux/amd64` to ensure images are built for the correct architecture (AMD64/x86_64) regardless of your local machine architecture (e.g., Mac M1/M2 ARM64).

### Manual Build (if needed)

#### Backend:
```bash
cd compliance_procedure_generator/backend
docker buildx build --platform linux/amd64 -f Dockerfile.gcp -t us-central1-docker.pkg.dev/PROJECT_ID/compliance-procedure-gen-backend/backend:TAG .
docker push us-central1-docker.pkg.dev/PROJECT_ID/compliance-procedure-gen-backend/backend:TAG
```

#### Frontend:
```bash
cd compliance_procedure_generator/frontend
docker buildx build --platform linux/amd64 -f Dockerfile.gcp -t us-central1-docker.pkg.dev/PROJECT_ID/compliance-procedure-gen-frontend/frontend:TAG .
docker push us-central1-docker.pkg.dev/PROJECT_ID/compliance-procedure-gen-frontend/frontend:TAG
```

**Important**: Always use `--platform linux/amd64` when building on Mac (especially M1/M2) to ensure compatibility with GCP Cloud Run.

## Terraform Configuration

### terraform.tfvars

After building and pushing images, update your `terraform.tfvars`:

```hcl
frontend_image = "us-central1-docker.pkg.dev/my-project/compliance-procedure-gen-frontend/frontend:latest"
backend_image  = "us-central1-docker.pkg.dev/my-project/compliance-procedure-gen-backend/backend:latest"
```

### Cloud Run Deployment

The `cp_generator` module deploys two Cloud Run services:

1. **Backend Service** (`google_cloud_run_v2_service.backend`)
   - Uses `var.backend_image`
   - Private (only accessible via VPC)
   - Port: 9090
   - Environment variables: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, LLM_API_KEY, DOCUMENTS_BUCKET

2. **Frontend Service** (`google_cloud_run_v2_service.frontend`)
   - Uses `var.frontend_image`
   - Public (internet-facing)
   - Port: 8080
   - Environment variable: BACKEND_URL (set to backend service URI)

## Environment Variables

### Frontend Container
- `BACKEND_URL`: Automatically set to the backend Cloud Run service URI
- `PORT`: Cloud Run sets this (default 8080)

### Backend Container
- `DB_HOST`: Cloud SQL private IP
- `DB_PORT`: PostgreSQL port (5432)
- `DB_NAME`: Database name
- `DB_USER`: Database username
- `DB_PASSWORD`: Retrieved from Secret Manager
- `LLM_API_KEY`: Retrieved from Secret Manager
- `DOCUMENTS_BUCKET`: Cloud Storage bucket name
- `NODE_ENV`: Environment (dev/staging/prod)

## File Structure

```
compliance_procedure_generator/
├── backend/
│   ├── Dockerfile           # AWS ECS version
│   └── Dockerfile.gcp       # GCP Cloud Run version ✓
├── frontend/
│   ├── Dockerfile           # AWS ECS version
│   ├── Dockerfile.gcp       # GCP Cloud Run version ✓
│   └── nginx.conf          # Nginx configuration template
├── Dockerfile.gcp          # OLD combined file (can be removed)
└── nginx.conf              # OLD nginx config (can be removed)
```

## Cleanup of Old Files

The following files in the generator root are **no longer used** and can be removed:

- `compliance_procedure_generator/Dockerfile.gcp` (old combined frontend+backend image)
- `compliance_procedure_generator/nginx.conf` (old nginx config for combined image)
- `compliance_procedure_admin/Dockerfile.gcp` (old combined admin image)

These have been replaced by separate Dockerfiles in each component directory.

## Deployment Workflow

1. **Build Infrastructure** (first time):
   ```bash
   cd terraform/gcp
   terraform init
   terraform apply -target=module.infrastructure
   ```

2. **Build and Push Images**:
   ```bash
   ./scripts/build_and_push.sh <project-id> <region>
   ```

3. **Update terraform.tfvars** with the image URIs

4. **Deploy Application**:
   ```bash
   terraform apply
   ```

5. **Access Application**:
   - Get frontend URL: `terraform output frontend_url`
   - Visit the URL in your browser

## Troubleshooting

### Images not found
- Ensure Artifact Registry repositories exist (created by infrastructure module)
- Verify you're authenticated: `gcloud auth configure-docker us-central1-docker.pkg.dev`
- Check repository names match: `{app_name}-gen-backend` and `{app_name}-gen-frontend`

### Frontend can't reach backend
- Check BACKEND_URL environment variable in frontend service
- Verify backend service is running: `gcloud run services list`
- Check VPC connector is properly configured
- Verify IAM permissions for frontend service account to invoke backend

### Container startup fails
- Check Cloud Run logs: `gcloud run services logs read SERVICE_NAME`
- Verify all environment variables are set correctly
- Check Secret Manager secrets exist and have values
