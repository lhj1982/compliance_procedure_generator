#!/bin/bash
set -e

# Build and push Docker images to Artifact Registry
# Usage: ./scripts/build_and_push.sh <project-id> <region> [tag] [app-name]
#
# Example: ./scripts/build_and_push.sh my-project us-central1 latest compliance-procedure

PROJECT_ID=${1:-$(gcloud config get-value project)}
REGION=${2:-us-central1}
TAG=${3:-latest}
APP_NAME=${4:-compliance-procedure}

if [ -z "$PROJECT_ID" ]; then
    echo "Error: GCP project ID not provided and not set in gcloud config"
    echo "Usage: $0 <project-id> <region> [tag] [app-name]"
    exit 1
fi

echo "=============================================="
echo "Building and pushing images to Artifact Registry"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Tag: $TAG"
echo "App Name: $APP_NAME"
echo "=============================================="

# Configure Docker for Artifact Registry
echo ""
echo "Configuring Docker for Artifact Registry..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Get the base directory (go up from terraform/gcp/scripts)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/../../.." && pwd )"

echo ""
echo "Base directory: $BASE_DIR"

# Build and push generator backend
echo ""
echo "=============================================="
echo "Building generator backend image..."
echo "=============================================="
cd "$BASE_DIR/compliance_procedure_generator/backend"
BACKEND_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${APP_NAME}-gen-backend/backend:${TAG}"
docker buildx build --platform linux/amd64 -f Dockerfile.gcp -t "$BACKEND_IMAGE" .
echo "Pushing generator backend image..."
docker push "$BACKEND_IMAGE"

# Build and push generator frontend
echo ""
echo "=============================================="
echo "Building generator frontend image..."
echo "=============================================="
cd "$BASE_DIR/compliance_procedure_generator/frontend"
FRONTEND_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${APP_NAME}-gen-frontend/frontend:${TAG}"
docker buildx build --platform linux/amd64 -f Dockerfile.gcp -t "$FRONTEND_IMAGE" .
echo "Pushing generator frontend image..."
docker push "$FRONTEND_IMAGE"

echo ""
echo "=============================================="
echo "Done! Images pushed:"
echo "=============================================="
echo "  Generator Backend:  $BACKEND_IMAGE"
echo "  Generator Frontend: $FRONTEND_IMAGE"
echo ""
echo "Update your terraform.tfvars with:"
echo "  backend_image  = \"$BACKEND_IMAGE\""
echo "  frontend_image = \"$FRONTEND_IMAGE\""
