# Testing Guide - GCP Cloud Run Deployment

## Overview

This guide explains how to test the compliance procedure generator deployed on GCP Cloud Run.

## Architecture Recap

- **Frontend**: Public Cloud Run service serving static files
  - Accessible from any browser
  - Calls backend API directly via JavaScript

- **Backend**: Public Cloud Run service with CORS protection
  - Publicly addressable but CORS-protected
  - Only accepts requests from `*.run.app` origins
  - Browser requests work because they come from frontend Cloud Run domain

- **Database**: Private Cloud SQL instance
  - Only accessible via VPC or bastion

## Testing the Application

### 1. Get Application URLs

From your local machine:

```bash
cd terraform/gcp/cp_generator
terraform output frontend_url
terraform output backend_url
```

Example outputs:
- Frontend: `https://cp-frontend-dev-123456.europe-north1.run.app`
- Backend: `https://cp-backend-dev-123456.europe-north1.run.app`

### 2. Test Frontend

Simply open the frontend URL in your browser:

```bash
# macOS
open $(terraform output -raw frontend_url)

# Linux
xdg-open $(terraform output -raw frontend_url)

# Or manually visit
# https://cp-frontend-dev-123456.europe-north1.run.app
```

**Expected behavior**:
- Application loads
- Team dropdown is populated
- You can select a team and see questions
- Browser console shows: `Using BACKEND_URL from APP_CONFIG: https://cp-backend-dev-xxx...`

### 3. Test Frontend Static Files

Check that nginx is serving files correctly:

```bash
FRONTEND_URL=$(terraform output -raw frontend_url)

# Health check
curl $FRONTEND_URL/health
# Expected: healthy

# Check static files
curl $FRONTEND_URL/static/app.js | head -20
curl $FRONTEND_URL/static/config.js
```

### 4. Test Backend CORS Protection

**From browser (should work)**:

Open browser console on the frontend page and run:

```javascript
fetch('https://cp-backend-dev-xxx.europe-north1.run.app/api/teams')
  .then(r => r.json())
  .then(d => console.log(d))
```

This should work because the request comes from a `*.run.app` origin.

**From curl/terminal (may work differently)**:

```bash
BACKEND_URL=$(terraform output -raw backend_url)

# Without Origin header - backend allows this
curl $BACKEND_URL/

# The backend is publicly addressable but CORS-protected
# Browser enforces CORS - curl doesn't have the same restrictions
curl $BACKEND_URL/api/teams
```

**Note**: CORS is enforced by browsers, not by curl. The backend is technically publicly accessible, but browsers will block requests from non-Cloud Run origins.

### 5. Test Backend API Endpoints

```bash
BACKEND_URL=$(terraform output -raw backend_url)

# Health check
curl $BACKEND_URL/
# Expected: {"status": "healthy", "service": "compliance-procedure-generator-api"}

# Get teams
curl $BACKEND_URL/api/teams
# Expected: [{"id": 1, "name": "Engineering"}, ...]

# Get questions for a team
curl $BACKEND_URL/api/teams/1/questions
# Expected: {"team_id": 1, "team_name": "...", "questions": [...]}
```

### 6. Test End-to-End Workflow

1. **Open frontend in browser**
2. **Select a team** from dropdown
3. **Fill in answers** to compliance questions
4. **Submit form**
5. **Download generated document**

**Check browser console for**:
- API base URL configuration
- API request/response logs
- Any CORS errors (there shouldn't be any)

**Check backend logs**:
```bash
gcloud run services logs read cp-backend-dev --region=europe-north1 --limit=50
```

## Testing from Bastion Server

The bastion can also be used for testing, especially for database-related operations.

### 1. SSH to Bastion

```bash
# Get SSH command
terraform output bastion_ssh_command

# Or manually
gcloud compute ssh cp-bastion-dev \
  --zone=europe-north1-a \
  --tunnel-through-iap \
  --project=YOUR_PROJECT_ID
```

### 2. Test Backend from Bastion

Once on the bastion:

```bash
BACKEND_URL="https://cp-backend-dev-xxx.europe-north1.run.app"

# Test health endpoint
curl $BACKEND_URL/

# Test API endpoints
curl $BACKEND_URL/api/teams
```

**Note**: Since the backend is public (with CORS protection), the bastion can access it without authentication tokens.

### 3. Test Database Connection from Bastion

```bash
# Start Cloud SQL proxy on bastion
cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:5432 &

# Connect to database
psql -h localhost -U compliance_user -d compliance_db

# Test queries
SELECT * FROM teams;
SELECT * FROM teams_compliance_procedures;
```

## Viewing Logs

### Frontend Logs

```bash
# Tail logs in real-time
gcloud run services logs tail cp-frontend-dev --region=europe-north1

# Read recent logs
gcloud run services logs read cp-frontend-dev --region=europe-north1 --limit=50

# Filter for errors
gcloud run services logs read cp-frontend-dev \
  --region=europe-north1 \
  --limit=100 \
  | grep -i error
```

### Backend Logs

```bash
# Tail logs in real-time
gcloud run services logs tail cp-backend-dev --region=europe-north1

# Read recent logs
gcloud run services logs read cp-backend-dev --region=europe-north1 --limit=50

# Filter by severity
gcloud run services logs read cp-backend-dev \
  --region=europe-north1 \
  --limit=100 \
  --log-filter="severity>=ERROR"
```

### Database Logs

```bash
# List recent operations
gcloud sql operations list --instance=cp-db-dev --limit=20

# Get specific operation details
gcloud sql operations describe OPERATION_ID
```

### Secret Access Logs

```bash
# See which services accessed secrets
gcloud logging read "resource.type=secretmanager.googleapis.com/Secret" \
  --limit=50 \
  --format=json
```

## Testing Different Scenarios

### Test CORS Protection

**Expected to work** (request from Cloud Run origin):
```javascript
// Run in browser console on frontend page
fetch('https://cp-backend-dev-xxx.run.app/api/teams')
  .then(r => r.json())
  .then(d => console.log('Success:', d))
  .catch(e => console.error('Error:', e))
```

**Expected to fail** (request from non-Cloud Run origin):

1. Open a different website (e.g., google.com)
2. Open browser console
3. Run:
```javascript
fetch('https://cp-backend-dev-xxx.run.app/api/teams')
  .then(r => r.json())
  .then(d => console.log('Success:', d))
  .catch(e => console.error('CORS Error:', e))
```

You should see a CORS error because the origin is not `*.run.app`.

### Test Database Connection

```bash
# From bastion, test connection
BACKEND_URL="https://cp-backend-dev-xxx.run.app"

# This should return data from database
curl $BACKEND_URL/api/teams
```

If this works, the backend can connect to the database via VPC.

### Test Cloud Storage Access

```bash
# Submit a compliance form via frontend
# Then check if document was uploaded to Cloud Storage

gcloud storage ls gs://cp-documents-dev-*/
```

### Test Secret Manager Access

Check backend logs to verify it loaded secrets:

```bash
gcloud run services logs read cp-backend-dev \
  --region=europe-north1 \
  --limit=100 \
  | grep -i "secret\|api.*key\|database"
```

## Troubleshooting

### Frontend can't load

**Symptom**: Browser shows "Site can't be reached"

**Check**:
```bash
# Verify frontend is deployed
gcloud run services describe cp-frontend-dev --region=europe-north1

# Check recent deployments
gcloud run revisions list --service=cp-frontend-dev --region=europe-north1
```

### Backend API returns 404

**Symptom**: API calls from frontend return 404

**Check**:
1. Verify backend URL in `frontend/static/config.js` is correct
2. Check backend is deployed:
```bash
gcloud run services describe cp-backend-dev --region=europe-north1
```
3. Test backend directly:
```bash
curl $(terraform output -raw backend_url)/
```

### CORS errors in browser

**Symptom**: Browser console shows CORS error

**Check**:
1. Verify backend CORS configuration allows `*.run.app`
2. Check frontend is actually hosted on `*.run.app` domain
3. View backend logs for CORS-related messages:
```bash
gcloud run services logs read cp-backend-dev --region=europe-north1 --limit=50
```

### Database connection failed

**Symptom**: Backend logs show "Database connection error"

**Check**:
1. Verify VPC connector is attached to backend:
```bash
gcloud run services describe cp-backend-dev \
  --region=europe-north1 \
  --format="value(spec.template.spec.vpcAccess.connector)"
```

2. Test database from bastion:
```bash
# SSH to bastion first
cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:5432 &
psql -h localhost -U compliance_user -d compliance_db -c "SELECT 1"
```

### Permission denied on secret

**Symptom**: Backend logs show "permission denied on secret"

**Check**:
```bash
# Verify backend service account has access
gcloud secrets get-iam-policy cp-secrets-dev

# Should show backend service account with secretAccessor role
```

**Fix**:
```bash
# Grant access manually if needed
gcloud secrets add-iam-policy-binding cp-secrets-dev \
  --member="serviceAccount:cp-backend-dev@PROJECT.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Generated documents not saving

**Symptom**: Document generation succeeds but download fails

**Check**:
```bash
# List documents in bucket
gcloud storage ls gs://cp-documents-dev-*/

# Check backend service account has storage permissions
gcloud storage buckets get-iam-policy gs://cp-documents-dev-*
```

## Performance Testing

### Test Cold Start Time

```bash
# Stop all instances (wait 15 minutes for scale to zero)
# Then test response time
time curl $(terraform output -raw frontend_url)/health
time curl $(terraform output -raw backend_url)/
```

### Test Concurrent Requests

```bash
BACKEND_URL=$(terraform output -raw backend_url)

# Send 10 concurrent requests
for i in {1..10}; do
  curl $BACKEND_URL/api/teams &
done
wait
```

### Monitor Resource Usage

```bash
# Check Cloud Run metrics in console
gcloud run services describe cp-backend-dev \
  --region=europe-north1 \
  --format="value(status.conditions)"
```

## Security Testing

### Verify Backend is Not Bypassing CORS

Try to access backend from curl with a fake Origin header:

```bash
curl -H "Origin: https://malicious-site.com" \
     $(terraform output -raw backend_url)/api/teams
```

The request will succeed from curl (curl doesn't enforce CORS), but browsers will block it.

### Verify Database is Private

Try to connect to database from local machine (should fail):

```bash
# This should fail because database has no public IP
psql -h $(terraform output -raw db_private_ip) -U compliance_user -d compliance_db
# Expected: Connection timeout or refused
```

### Verify Secrets Are Not Exposed

Check that secrets are not visible in frontend:

```bash
curl $(terraform output -raw frontend_url)/static/config.js
# Should NOT contain any secrets, only backend URL
```

## Next Steps

After successful testing:

1. **Set up monitoring** - Configure Cloud Monitoring alerts
2. **Enable Cloud CDN** - For faster static file delivery (optional)
3. **Configure custom domain** - Map custom domain to frontend
4. **Set up CI/CD** - Automate deployments
5. **Enable Cloud Armor** - Add DDoS protection (optional)

## Useful Commands Reference

```bash
# Get all outputs
terraform output

# Tail frontend logs
gcloud run services logs tail cp-frontend-dev --region=europe-north1

# Tail backend logs
gcloud run services logs tail cp-backend-dev --region=europe-north1

# SSH to bastion
terraform output bastion_ssh_command | sh

# List all Cloud Run services
gcloud run services list --region=europe-north1

# List all secrets
gcloud secrets list

# Check Cloud SQL status
gcloud sql instances describe cp-db-dev
```
