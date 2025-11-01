# Testing Guide

## Overview

This guide explains how to test the backend API from the bastion server.

## Why Bastion Can Access Backend

The bastion service account has been granted `roles/run.invoker` permission on the backend Cloud Run service. This allows you to:
- Test backend API endpoints
- Debug issues
- Verify backend functionality
- Check backend health

## Prerequisites

1. Terraform has been applied successfully
2. Backend Cloud Run service is deployed
3. You have access to the GCP project

## Quick Test

### 1. Get the SSH Command

```bash
# From your local machine
cd terraform/gcp
terraform output bastion_ssh_command
```

Copy and run the command shown.

### 2. SSH to Bastion

```bash
# Example output from above
gcloud compute ssh cp-bastion-dev --zone=europe-north1-a --tunnel-through-iap
```

### 3. Test Backend

Once on the bastion, run:

```bash
# Get backend test command
terraform output test_backend_command

# Or manually:
TOKEN=$(gcloud auth print-identity-token)
BACKEND_URL="https://cp-backend-dev-xxxxxxxxxxxx-uc.a.run.app"

# Test health endpoint
curl -H "Authorization: Bearer $TOKEN" $BACKEND_URL/health
```

## Detailed Testing

### Get Backend URL

From your local machine:
```bash
cd terraform/gcp
terraform output backend_url
```

Example output: `https://cp-backend-dev-xxxxx-uc.a.run.app`

### SSH to Bastion

```bash
gcloud compute ssh cp-bastion-dev \
  --zone=europe-north1-a \
  --tunnel-through-iap \
  --project=YOUR_PROJECT_ID
```

### Test Backend Endpoints

Once connected to bastion:

#### 1. Test Health Endpoint

```bash
TOKEN=$(gcloud auth print-identity-token)
BACKEND_URL="https://cp-backend-dev-xxxxx-uc.a.run.app"

curl -H "Authorization: Bearer $TOKEN" $BACKEND_URL/health
```

Expected response:
```json
{"status": "healthy"}
```

#### 2. Test API Endpoints

```bash
# GET request
curl -H "Authorization: Bearer $TOKEN" \
     $BACKEND_URL/api/questions

# POST request
curl -X POST \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"question":"What is the procedure for...?"}' \
     $BACKEND_URL/api/generate
```

#### 3. Check Environment Variables (Debug)

```bash
# If your backend has a debug endpoint
curl -H "Authorization: Bearer $TOKEN" \
     $BACKEND_URL/api/debug/env
```

#### 4. Test Database Connection

```bash
# If your backend has a database health check
curl -H "Authorization: Bearer $TOKEN" \
     $BACKEND_URL/api/health/database
```

## Testing Without Authentication (Will Fail)

To verify that backend is properly secured, try accessing without auth:

```bash
# This should fail with 403 Forbidden
curl https://cp-backend-dev-xxxxx-uc.a.run.app/health
```

Expected response:
```
<html><head>
<meta http-equiv="content-type" content="text/html;charset=utf-8">
<title>403 Forbidden</title>
</head>
<body text=#000000 bgcolor=#ffffff>
<h1>Error: Forbidden</h1>
<h2>Your client does not have permission to get URL...</h2>
</body></html>
```

This confirms that the backend is properly secured and requires authentication.

## Troubleshooting

### Error: "Your client does not have permission"

**Problem**: Getting 403 Forbidden even with token

**Solutions**:

1. Verify bastion service account has permission:
   ```bash
   gcloud run services get-iam-policy cp-backend-dev \
     --region=europe-north1 \
     --project=YOUR_PROJECT_ID
   ```

   Should see:
   ```yaml
   - members:
     - serviceAccount:cp-bastion-dev@PROJECT.iam.gserviceaccount.com
     role: roles/run.invoker
   ```

2. Verify you're using bastion's service account:
   ```bash
   # On bastion
   gcloud auth list
   ```

   Should show bastion service account as active.

3. Refresh token:
   ```bash
   TOKEN=$(gcloud auth print-identity-token)
   echo $TOKEN  # Should show a long JWT token
   ```

### Error: "Could not resolve host"

**Problem**: DNS not working

**Solution**:
```bash
# On bastion
ping 8.8.8.8  # Test internet connectivity
nslookup cp-backend-dev-xxxxx-uc.a.run.app  # Test DNS
```

### Error: "Connection refused"

**Problem**: Backend service is not running

**Solution**:
```bash
# From local machine
gcloud run services describe cp-backend-dev \
  --region=europe-north1 \
  --project=YOUR_PROJECT_ID

# Check if service is ready
gcloud run services list --project=YOUR_PROJECT_ID
```

## Testing Workflow

### Complete Testing Checklist

1. **SSH to Bastion**
   ```bash
   gcloud compute ssh cp-bastion-dev --tunnel-through-iap --zone=europe-north1-a
   ```

2. **Get Auth Token**
   ```bash
   TOKEN=$(gcloud auth print-identity-token)
   ```

3. **Set Backend URL**
   ```bash
   BACKEND_URL="https://cp-backend-dev-xxxxx-uc.a.run.app"
   ```

4. **Test Health**
   ```bash
   curl -H "Authorization: Bearer $TOKEN" $BACKEND_URL/health
   ```

5. **Test API Endpoints**
   ```bash
   # List questions
   curl -H "Authorization: Bearer $TOKEN" $BACKEND_URL/api/questions

   # Generate procedure
   curl -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"answers":[...]}' \
        $BACKEND_URL/api/generate
   ```

6. **Check Logs**
   ```bash
   # From local machine
   gcloud run services logs read cp-backend-dev \
     --region=europe-north1 \
     --limit=50
   ```

## Advanced Testing

### Using Variables for Cleaner Commands

Create a test script on bastion:

```bash
# On bastion, create ~/test-backend.sh
cat > ~/test-backend.sh << 'EOF'
#!/bin/bash

# Get token
TOKEN=$(gcloud auth print-identity-token)

# Backend URL (update this)
BACKEND_URL="https://cp-backend-dev-xxxxx-uc.a.run.app"

# Test health
echo "Testing health endpoint..."
curl -H "Authorization: Bearer $TOKEN" $BACKEND_URL/health
echo ""

# Test API
echo "Testing API endpoint..."
curl -H "Authorization: Bearer $TOKEN" $BACKEND_URL/api/questions
echo ""

echo "Done!"
EOF

chmod +x ~/test-backend.sh
```

Then simply run:
```bash
./test-backend.sh
```

### Testing with jq for Pretty JSON

```bash
# Install jq on bastion
sudo apt-get install -y jq

# Use jq to format JSON responses
TOKEN=$(gcloud auth print-identity-token)
BACKEND_URL="https://cp-backend-dev-xxxxx-uc.a.run.app"

curl -s -H "Authorization: Bearer $TOKEN" $BACKEND_URL/api/questions | jq .
```

### Load Testing

```bash
# Simple load test - 10 requests
for i in {1..10}; do
  TOKEN=$(gcloud auth print-identity-token)
  curl -H "Authorization: Bearer $TOKEN" \
       $BACKEND_URL/health &
done
wait

echo "Load test complete"
```

## Security Notes

### What Bastion Can Do

✅ Invoke backend Cloud Run service (via IAM)
✅ Access Cloud SQL database (via Cloud SQL proxy)
✅ Read Cloud Run logs (if given permission)
✅ Access Secret Manager (if given permission)

### What Bastion Cannot Do

❌ Access backend without authentication token
❌ Access Secret Manager by default (needs explicit permission)
❌ Access Cloud Storage by default (needs explicit permission)
❌ Create or modify Cloud Run services

### Best Practices

1. **Use IAP Tunnel**: Never expose bastion with external IP
2. **Rotate Tokens**: Tokens expire after 1 hour, get fresh ones for each session
3. **Limit Bastion Access**: Only grant access to users who need it
4. **Monitor Usage**: Check bastion logs regularly
5. **Use Preemptible in Dev**: Saves costs and forces infrastructure-as-code discipline

## Comparison: Frontend vs Bastion Access

### Frontend Service Account

```bash
# Frontend calls backend WITHOUT Authorization header
# Cloud Run automatically injects identity token when using service account
```

Frontend nginx proxies to backend like:
```nginx
proxy_pass $BACKEND_URL;
# Cloud Run adds authentication automatically via service account
```

### Bastion Service Account

```bash
# Bastion calls backend WITH Authorization header
TOKEN=$(gcloud auth print-identity-token)
curl -H "Authorization: Bearer $TOKEN" $BACKEND_URL/api/endpoint
```

Both use the same IAM mechanism (`roles/run.invoker`) but different invocation methods.
