#!/bin/bash
set -e

# Verify Secret Manager permissions for Cloud Run backend service
# Usage: ./scripts/verify_permissions.sh <project-id> <region> [environment] [app-name]

PROJECT_ID=${1:-$(gcloud config get-value project)}
REGION=${2:-europe-north1}
ENVIRONMENT=${3:-dev}
APP_NAME=${4:-cp}

if [ -z "$PROJECT_ID" ]; then
    echo "Error: GCP project ID not provided and not set in gcloud config"
    echo "Usage: $0 <project-id> <region> [environment] [app-name]"
    exit 1
fi

echo "=============================================="
echo "Verifying Secret Manager Permissions"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo "App Name: $APP_NAME"
echo "=============================================="
echo ""

# Construct resource names
SECRET_NAME="${APP_NAME}-secrets-${ENVIRONMENT}"
BACKEND_SA="${APP_NAME}-backend-${ENVIRONMENT}@${PROJECT_ID}.iam.gserviceaccount.com"
BACKEND_SERVICE="${APP_NAME}-backend-${ENVIRONMENT}"

echo "Secret Name: $SECRET_NAME"
echo "Backend Service Account: $BACKEND_SA"
echo "Backend Cloud Run Service: $BACKEND_SERVICE"
echo ""

# Check if secret exists
echo "1. Checking if secret exists..."
if gcloud secrets describe $SECRET_NAME --project=$PROJECT_ID &>/dev/null; then
    echo "   ✓ Secret exists: $SECRET_NAME"
else
    echo "   ✗ Secret NOT found: $SECRET_NAME"
    echo ""
    echo "Available secrets:"
    gcloud secrets list --project=$PROJECT_ID
    exit 1
fi
echo ""

# Check if service account exists
echo "2. Checking if backend service account exists..."
if gcloud iam service-accounts describe $BACKEND_SA --project=$PROJECT_ID &>/dev/null; then
    echo "   ✓ Service account exists: $BACKEND_SA"
else
    echo "   ✗ Service account NOT found: $BACKEND_SA"
    echo ""
    echo "Available service accounts:"
    gcloud iam service-accounts list --project=$PROJECT_ID
    exit 1
fi
echo ""

# Check secret IAM policy
echo "3. Checking secret IAM policy..."
SECRET_POLICY=$(gcloud secrets get-iam-policy $SECRET_NAME --project=$PROJECT_ID --format=json)
if echo "$SECRET_POLICY" | grep -q "$BACKEND_SA"; then
    echo "   ✓ Backend service account has access to secret"
    echo ""
    echo "   IAM Policy:"
    gcloud secrets get-iam-policy $SECRET_NAME --project=$PROJECT_ID
else
    echo "   ✗ Backend service account does NOT have access to secret"
    echo ""
    echo "   Current IAM Policy:"
    gcloud secrets get-iam-policy $SECRET_NAME --project=$PROJECT_ID
    echo ""
    echo "   To fix, run:"
    echo "   gcloud secrets add-iam-policy-binding $SECRET_NAME \\"
    echo "     --member=\"serviceAccount:$BACKEND_SA\" \\"
    echo "     --role=\"roles/secretmanager.secretAccessor\" \\"
    echo "     --project=$PROJECT_ID"
    exit 1
fi
echo ""

# Check if Cloud Run service exists
echo "4. Checking if Cloud Run service exists..."
if gcloud run services describe $BACKEND_SERVICE --region=$REGION --project=$PROJECT_ID &>/dev/null; then
    echo "   ✓ Cloud Run service exists: $BACKEND_SERVICE"
else
    echo "   ✗ Cloud Run service NOT found: $BACKEND_SERVICE"
    echo ""
    echo "Available Cloud Run services:"
    gcloud run services list --project=$PROJECT_ID
    exit 1
fi
echo ""

# Check Cloud Run service account
echo "5. Checking Cloud Run service's service account..."
ACTUAL_SA=$(gcloud run services describe $BACKEND_SERVICE \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format="value(spec.template.spec.serviceAccountName)")

if [ "$ACTUAL_SA" == "$BACKEND_SA" ]; then
    echo "   ✓ Cloud Run is using correct service account: $ACTUAL_SA"
else
    echo "   ✗ Cloud Run is using WRONG service account"
    echo "   Expected: $BACKEND_SA"
    echo "   Actual:   $ACTUAL_SA"
    echo ""
    echo "   To fix, redeploy with Terraform or run:"
    echo "   gcloud run services update $BACKEND_SERVICE \\"
    echo "     --service-account=$BACKEND_SA \\"
    echo "     --region=$REGION \\"
    echo "     --project=$PROJECT_ID"
    exit 1
fi
echo ""

# Check secret value exists
echo "6. Checking if secret has a value..."
if gcloud secrets versions access latest --secret=$SECRET_NAME --project=$PROJECT_ID &>/dev/null; then
    echo "   ✓ Secret has a value"
    echo ""
    echo "   Secret structure (first 100 chars):"
    gcloud secrets versions access latest --secret=$SECRET_NAME --project=$PROJECT_ID | head -c 100
    echo "..."
else
    echo "   ✗ Secret has NO value"
    echo ""
    echo "   To fix, add a secret version:"
    echo "   echo '{\"llm_api_key\":\"your-key\",\"db_password\":\"your-password\"}' | \\"
    echo "     gcloud secrets versions add $SECRET_NAME --data-file=- --project=$PROJECT_ID"
    exit 1
fi
echo ""
echo ""

# Summary
echo "=============================================="
echo "✓ All permissions verified successfully!"
echo "=============================================="
echo ""
echo "Backend service should be able to access secrets."
echo ""
echo "To test from backend, the APP_SECRETS environment variable should contain:"
echo "  {\"llm_api_key\":\"...\",\"db_password\":\"...\"}"
echo ""
echo "Check backend logs:"
echo "  gcloud run services logs read $BACKEND_SERVICE --region=$REGION --limit=50"
