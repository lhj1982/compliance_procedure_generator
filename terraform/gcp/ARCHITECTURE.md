# GCP Architecture - Simplified & Cost-Effective

## Overview

This is a **simple, secure, and cost-effective** architecture for the compliance procedure generator on GCP.

## Architecture Diagram

```
Internet
    |
    | HTTPS (443)
    |
    +------------------+------------------+
    |                  |                  |
    v                  v                  |
[Frontend Cloud Run]  [Backend Cloud Run]|  <-- Both internal GCP only
    |                  |                  |    - Frontend: Static files (nginx)
    |                  |                  |    - Backend: Python Flask API
    |                  |                  |
    | Browser calls    | VPC Connector    |
    | backend directly |                  |
    |                  v                  v
    |              [Cloud SQL]    [Cloud Storage]
    |                  |          [Secret Manager]
    |                  |
    |                  |
    +------------------+
           |
           | All requests from *.run.app domains only (GCP Cloud Run)
           | CORS configured to allow only Cloud Run origins
           v
    User's Browser
    (JavaScript makes API calls directly to backend URL)


[Bastion VM]          <-- For admin access to database
    | IAP Tunnel (SSH)
    v
[Cloud SQL]
```

## Key Design Decisions

### ✅ No Load Balancer

**Why**: Cloud Run already provides:
- Free HTTPS endpoints with SSL certificates
- Global edge locations
- Auto-scaling
- DDoS protection

**Cost Savings**: ~$18-25/month by not using a load balancer

### ✅ Browser-Direct API Architecture

- **Frontend**: Public Cloud Run service serving static files only
  - No reverse proxy, no backend URL in environment
  - JavaScript includes backend URL in config.js

- **Backend**: Public Cloud Run service with CORS protection
  - Ingress: `INGRESS_TRAFFIC_ALL` (allows browser requests)
  - CORS: Only accepts requests from `*.run.app` domains
  - Browser calls backend API directly with full URL

**Why This Works**:
- Backend is publicly addressable (has HTTPS URL)
- But CORS only allows requests from `*.run.app` origins
- Browser makes requests with `Origin: https://frontend-xxx.run.app`
- Backend CORS validates origin is from `*.run.app` domain
- Any request from non-Cloud Run domain is rejected by CORS
- This effectively restricts backend to GCP Cloud Run environment

### ✅ Two-Layer Security

**Frontend (Public)**:
- IAM: `allUsers` can invoke
- Exposed to internet via Cloud Run's built-in HTTPS
- Only serves static HTML/CSS/JS files
- No environment variables, no secrets
- No proxy configuration needed

**Backend (Public with CORS Protection)**:
- Ingress: `INGRESS_TRAFFIC_ALL` (allows browser requests)
- CORS: Only `*.run.app` origins accepted
- IAM: `allUsers` can invoke
- Handles all sensitive operations (DB, secrets, storage)
- CORS protection restricts to Cloud Run frontend domains only

### ✅ VPC Connectivity

- **Backend** Cloud Run uses **VPC Connector** to access Cloud SQL
- **Frontend** Cloud Run doesn't need VPC (just serves static files)
- VPC has two subnets:
  - **Public subnet**: Bastion host
  - **Private subnet**: Cloud SQL

### ✅ Cost Optimization

| Resource | Config | Monthly Cost (estimate) |
|----------|--------|------------------------|
| Frontend Cloud Run | Scale to 0, 256Mi RAM | $0-5 |
| Backend Cloud Run | Scale to 0, 512Mi RAM | $0-10 |
| Cloud SQL (db-f1-micro) | Smallest instance | ~$7 |
| Bastion (e2-micro) | Preemptible in dev | ~$3-7 |
| VPC Connector | Minimum config | ~$7-8 |
| Cloud Storage | Pay per use | ~$0-1 |
| Secret Manager | 6 accesses/month | <$0.01 |
| **Total** | | **~$17-38/month** |

**Production**: Scale up Cloud SQL to `db-g1-small` (~$25/month) and disable preemptible bastion.

## Components

### 1. Frontend Cloud Run Service

**Purpose**: Serve static HTML/CSS/JS files (no backend proxy)

**Configuration**:
- Image: Nginx serving static files
- Port: 8082
- Memory: 256Mi
- CPU: 1
- Scaling: 0-5 instances (0-10 in prod)
- IAM: `allUsers` can invoke (public access)
- Service Account: `{app-name}-frontend-{env}`

**Environment Variables**: None needed

**Network**: No VPC connector needed (just static files)

**JavaScript Configuration**:
- Backend URL configured in `static/config.js`
- Must be updated before building frontend image
- Example: `BACKEND_URL: "https://cp-backend-dev-xxx.run.app"`

### 2. Backend Cloud Run Service

**Purpose**: Handle API requests, database operations, LLM integration

**Configuration**:
- Image: Python Flask application
- Port: 9090
- Memory: 512Mi
- CPU: 1
- Scaling: 0-3 instances (0-10 in prod)
- Ingress: `INGRESS_TRAFFIC_ALL` (allows browser requests)
- IAM: `allUsers` can invoke
- Service Account: `{app-name}-backend-{env}`
- CORS: Only `*.run.app` origins allowed (enforced in application code)

**Environment Variables**:
- `APP_SECRETS`: JSON from Secret Manager (`{"llm_api_key": "...", "db_password": "..."}`)
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`: Database connection
- `DOCUMENTS_BUCKET`: Cloud Storage bucket name
- `LLM_BASE_URL`: LLM API base URL
- `NODE_ENV`: Environment (dev/staging/prod)
- `GCP_PROJECT_ID`: GCP project ID

**IAM Permissions** (via service account):
- `secretmanager.secretAccessor` on app secrets
- `storage.objectAdmin` on documents bucket

**Network**:
- VPC Connector for accessing Cloud SQL
- Egress: `PRIVATE_RANGES_ONLY`

### 3. Cloud SQL (PostgreSQL)

**Purpose**: Store application data

**Configuration**:
- Tier: `db-f1-micro` (dev) or `db-g1-small` (prod)
- Private IP only (no public IP)
- Accessible only via VPC

**Access**:
- Backend Cloud Run (via VPC Connector)
- Bastion (via VPC)

### 4. Bastion Host

**Purpose**: Admin access to database and private resources

**Configuration**:
- Machine Type: `e2-micro` (cheapest)
- Zone: `{region}-a`
- No external IP (uses IAP for SSH)
- Preemptible in dev (saves 60-91%)

**Access Method**:
```bash
gcloud compute ssh bastion --tunnel-through-iap
```

**Installed Tools**:
- PostgreSQL client
- Cloud SQL proxy
- gcloud CLI

### 5. VPC Network

**Subnets**:
- **Public**: `10.0.0.0/24` - Bastion host
- **Private**: `10.0.1.0/24` - Cloud SQL

**VPC Connector**: `10.8.0.0/28` (fixed CIDR for connector)

**Firewall Rules**:
- Allow SSH from IAP to bastion (`35.235.240.0/20` → port 22)
- Cloud Run → Cloud SQL (automatic via VPC connector)

### 6. Secret Manager

**Single Combined Secret**: `{app-name}-secrets-{env}`

**Structure**:
```json
{
  "llm_api_key": "your-key",
  "db_password": "your-password"
}
```

**Access**: Backend service account has `secretAccessor` role

### 7. Cloud Storage

**Bucket**: `{app-name}-documents-{env}-{project-number}`

**Configuration**:
- Uniform bucket-level access
- Versioning enabled
- Lifecycle: Delete after 90 days
- Private (no public access)

**Access**: Backend service account has `objectAdmin` role

## Security Model

### Public Access
- ✅ Frontend Cloud Run service (HTTPS only, static files)
- ✅ Backend Cloud Run service (HTTPS only, CORS-protected API)

### CORS-Protected Access
- ✅ Backend API endpoints
  - Publicly addressable but CORS-protected
  - Only accepts requests from `*.run.app` origins
  - Rejects requests from any other domain
  - Browser requests work because they come from frontend Cloud Run domain

### Private (VPC-only) Access
- ✅ Cloud SQL database
- ✅ Bastion host (via IAP tunnel)

### IAM-Controlled Access
- ✅ Secret Manager (backend service account only)
- ✅ Cloud Storage (backend service account only)

### How Backend Security Works
1. **Public Endpoint**: Backend has public HTTPS URL (required for browser requests)
2. **CORS Validation**: Only accepts requests with `Origin: https://*.run.app`
3. **Result**: Backend only responds to browser requests from Cloud Run frontend
4. **User Flow**: Browser loads Frontend (*.run.app) → JavaScript calls Backend → CORS validates origin → Response
5. **Protection**: Requests from non-Cloud Run domains are blocked by CORS

**Important**: The backend is technically "public" but CORS protection ensures only the Cloud Run frontend can successfully make API calls to it.

## Traffic Flow

### User Request Flow

1. **User** → `https://frontend-xxxxx.run.app` (loads HTML/CSS/JS)
2. **Frontend Cloud Run** → Serves static files to browser
3. **Browser JavaScript** → Makes API call to `https://backend-xxxxx.run.app/api/teams`
   - Request includes `Origin: https://frontend-xxxxx.run.app` header
4. **Backend Cloud Run** → Validates CORS origin (*.run.app)
5. **Backend** → Queries Cloud SQL / Secret Manager / Cloud Storage
6. **Backend** → Returns JSON response to browser
7. **Browser** → Updates UI with response data

### Admin Database Access Flow

1. **Admin** → SSH to bastion via IAP tunnel
   ```bash
   gcloud compute ssh bastion --tunnel-through-iap
   ```
2. **Bastion** → Start Cloud SQL proxy
   ```bash
   cloud_sql_proxy -instances=project:region:instance=tcp:5432
   ```
3. **Admin** → Connect to database via proxy
   ```bash
   psql -h localhost -U user -d database
   ```

### Admin Backend Testing Flow

The bastion can also test the backend API directly:

1. **Admin** → SSH to bastion via IAP tunnel
   ```bash
   gcloud compute ssh bastion --tunnel-through-iap
   ```
2. **Bastion** → Get auth token and test backend
   ```bash
   # Get authentication token (bastion uses its service account)
   TOKEN=$(gcloud auth print-identity-token)

   # Test backend health endpoint
   curl -H "Authorization: Bearer $TOKEN" https://cp-backend-dev-xxxx.run.app/health

   # Test backend API
   curl -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        https://cp-backend-dev-xxxx.run.app/api/endpoint
   ```

## Deployment Instructions

### 1. Deploy Infrastructure

```bash
cd terraform/gcp/infrastructure
terraform init
terraform apply
```

This creates: VPC, Cloud SQL, Secret Manager, Cloud Storage, Artifact Registry

### 2. Deploy Backend First

```bash
cd terraform/gcp
./scripts/build_and_push.sh <project-id> <region>
```

### 3. Update backend image in terraform.tfvars

```hcl
backend_image = "europe-north1-docker.pkg.dev/PROJECT/cp-gen-backend/backend:latest"
```

### 4. Deploy backend Cloud Run

```bash
cd terraform/gcp/cp_generator
terraform init
terraform apply
```

### 5. Get backend URL and update frontend config

```bash
# Get backend URL
terraform output backend_url

# Update frontend/static/config.js with the backend URL
# Replace BACKEND_URL_PLACEHOLDER with actual backend URL
# Example: https://cp-backend-dev-xxx.europe-north1.run.app
```

Or use the command from terraform output:
```bash
terraform output config_update_command
```

### 6. Build and push frontend image

```bash
cd terraform/gcp
./scripts/build_and_push.sh <project-id> <region>
```

### 7. Update frontend image and deploy

```hcl
frontend_image = "europe-north1-docker.pkg.dev/PROJECT/cp-gen-frontend/frontend:latest"
```

```bash
cd terraform/gcp/cp_generator
terraform apply
```

### 8. Get Frontend URL

```bash
terraform output frontend_url
```

Example output: `https://cp-frontend-dev-xxxxxxxxxxxx.europe-north1.run.app`

## Accessing the Application

### Public Access (Users)
Simply visit the frontend URL from anywhere:
```
https://cp-frontend-dev-xxxxxxxxxxxx-uc.a.run.app
```

### Admin Access (Database)
1. SSH to bastion via IAP:
   ```bash
   gcloud compute ssh cp-bastion-dev --tunnel-through-iap --zone=europe-north1-a
   ```

2. Start Cloud SQL proxy on bastion:
   ```bash
   cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:5432
   ```

3. Connect to database:
   ```bash
   psql -h localhost -U compliance_user -d compliance_db
   ```

### Admin Access (Testing Backend API)
1. SSH to bastion via IAP:
   ```bash
   gcloud compute ssh cp-bastion-dev --tunnel-through-iap --zone=europe-north1-a
   ```

2. Test backend API with authentication:
   ```bash
   # Get auth token (automatically uses bastion service account)
   TOKEN=$(gcloud auth print-identity-token)

   # Get backend URL from terraform output
   BACKEND_URL=$(terraform output -raw backend_url)

   # Test backend health
   curl -H "Authorization: Bearer $TOKEN" $BACKEND_URL/health

   # Test backend API endpoint
   curl -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"key":"value"}' \
        $BACKEND_URL/api/your-endpoint
   ```

## Monitoring & Logging

### Cloud Run Logs
```bash
# Frontend logs
gcloud run services logs read cp-frontend-dev --region=europe-north1

# Backend logs
gcloud run services logs read cp-backend-dev --region=europe-north1
```

### Secret Access Logs
```bash
gcloud logging read "resource.type=secretmanager.googleapis.com/Secret" --limit 50
```

### Database Logs
```bash
gcloud sql operations list --instance=cp-db-dev
```

## Cost Optimization Tips

### Development Environment
- ✅ Use `db-f1-micro` for Cloud SQL (~$7/month)
- ✅ Use preemptible bastion (~$3/month vs $7/month)
- ✅ Set Cloud Run min instances to 0 (scale to zero)
- ✅ Use `PRIVATE_RANGES_ONLY` egress (saves data egress costs)

### Production Environment
- Upgrade Cloud SQL to `db-g1-small` (~$25/month)
- Use non-preemptible bastion for reliability
- Set Cloud Run min instances to 1 for faster response
- Enable Cloud CDN if needed (adds ~$1-5/month)

## Comparison with Load Balancer Approach

### With Load Balancer (Previous)
```
Cost: ~$35-55/month
- Load Balancer: $18-25/month
- Cloud Run: $7-15/month
- Other: $10-15/month
```

### Without Load Balancer (Current)
```
Cost: ~$17-38/month
- Cloud Run: $7-15/month (direct access)
- Other: $10-23/month

Savings: ~$18-25/month (30-50%)
```

### What You Get with Direct Cloud Run

Both approaches provide:
- ✅ HTTPS/SSL certificates
- ✅ Global distribution
- ✅ DDoS protection
- ✅ Auto-scaling
- ✅ Health checks
- ✅ Monitoring

The load balancer adds:
- Custom domain support (can be added to Cloud Run too)
- URL-based routing (not needed - frontend proxies)
- Multiple backend services (not needed - we have 1 frontend)

**Conclusion**: For this use case, the load balancer adds no value but costs $200-300/year.
