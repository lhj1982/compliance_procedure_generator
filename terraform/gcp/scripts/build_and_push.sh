#!/bin/bash
set -e

# Build and push Docker images to GCR
# Usage: ./scripts/build_and_push.sh <project-id> <tag>

PROJECT_ID=${1:-$(gcloud config get-value project)}
TAG=${2:-latest}

if [ -z "$PROJECT_ID" ]; then
    echo "Error: GCP project ID not provided and not set in gcloud config"
    echo "Usage: $0 <project-id> [tag]"
    exit 1
fi

echo "Building and pushing images to GCR for project: $PROJECT_ID with tag: $TAG"

# Configure Docker for GCR
echo "Configuring Docker for GCR..."
gcloud auth configure-docker gcr.io

# Build and push frontend (generator)
echo "Building frontend image..."
cd ../../compliance_procedure_generator
docker build -f Dockerfile.gcp -t gcr.io/$PROJECT_ID/compliance-frontend:$TAG .
echo "Pushing frontend image..."
docker push gcr.io/$PROJECT_ID/compliance-frontend:$TAG

# Build and push admin
echo "Building admin image..."
cd ../compliance_procedure_admin
docker build -f Dockerfile.gcp -t gcr.io/$PROJECT_ID/compliance-admin:$TAG .
echo "Pushing admin image..."
docker push gcr.io/$PROJECT_ID/compliance-admin:$TAG

echo "Done! Images pushed:"
echo "  - gcr.io/$PROJECT_ID/compliance-frontend:$TAG"
echo "  - gcr.io/$PROJECT_ID/compliance-admin:$TAG"
echo ""
echo "Update your terraform.tfvars with:"
echo "  frontend_image = \"gcr.io/$PROJECT_ID/compliance-frontend:$TAG\""
echo "  admin_image = \"gcr.io/$PROJECT_ID/compliance-admin:$TAG\""
