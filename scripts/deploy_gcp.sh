#!/bin/bash
set -e

# GCP Deployment Script for Compliance Procedure Generator
# Usage: ./scripts/deploy_gcp.sh [project-id] [region]

PROJECT_ID=${1:-""}
REGION=${2:-"us-central1"}
APP_NAME="compliance-procedure-gen"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}===================================${NC}"
echo -e "${GREEN}GCP Deployment Script${NC}"
echo -e "${GREEN}===================================${NC}"

# Check if project ID is provided
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: GCP Project ID is required${NC}"
    echo "Usage: ./scripts/deploy_gcp.sh [project-id] [region]"
    exit 1
fi

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Please install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    echo "Please install from: https://www.terraform.io/downloads"
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install from: https://docs.docker.com/get-docker/"
    exit 1
fi

echo -e "${YELLOW}Project ID: ${PROJECT_ID}${NC}"
echo -e "${YELLOW}Region: ${REGION}${NC}"
echo ""

# Step 1: Authenticate and configure gcloud
echo -e "${GREEN}Step 1: Configuring gcloud...${NC}"
gcloud config set project $PROJECT_ID
gcloud services enable artifactregistry.googleapis.com

# Step 2: Configure Docker authentication
echo -e "${GREEN}Step 2: Configuring Docker authentication...${NC}"
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Step 3: Check if Artifact Registry repository exists
echo -e "${GREEN}Step 3: Checking Artifact Registry...${NC}"
REPO_EXISTS=$(gcloud artifacts repositories list --location=${REGION} --format="value(name)" --filter="name:${APP_NAME}-repo" 2>/dev/null || echo "")

if [ -z "$REPO_EXISTS" ]; then
    echo -e "${YELLOW}Creating Artifact Registry repository...${NC}"
    gcloud artifacts repositories create ${APP_NAME}-repo \
        --repository-format=docker \
        --location=${REGION} \
        --description="Docker repository for compliance procedure generator"
fi

# Step 4: Build Docker images
echo -e "${GREEN}Step 4: Building Docker images...${NC}"

echo "Building backend image..."
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${APP_NAME}-repo/backend:latest ./backend

echo "Building frontend image..."
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${APP_NAME}-repo/frontend:latest ./frontend

# Step 5: Push Docker images
echo -e "${GREEN}Step 5: Pushing Docker images to Artifact Registry...${NC}"

echo "Pushing backend image..."
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${APP_NAME}-repo/backend:latest

echo "Pushing frontend image..."
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${APP_NAME}-repo/frontend:latest

# Step 6: Deploy with Terraform
echo -e "${GREEN}Step 6: Deploying infrastructure with Terraform...${NC}"
cd terraform/gcp

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    terraform init
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Warning: terraform.tfvars not found. Creating from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${RED}Please edit terraform/gcp/terraform.tfvars with your configuration${NC}"
    echo -e "${RED}Then run this script again.${NC}"
    exit 1
fi

# Check for required environment variables
if [ -z "$TF_VAR_llm_api_key" ]; then
    echo -e "${RED}Error: TF_VAR_llm_api_key environment variable is not set${NC}"
    echo "Please set it: export TF_VAR_llm_api_key='your-api-key'"
    exit 1
fi

if [ -z "$TF_VAR_db_password" ]; then
    echo -e "${RED}Error: TF_VAR_db_password environment variable is not set${NC}"
    echo "Please set it: export TF_VAR_db_password='your-secure-password'"
    exit 1
fi

# Apply Terraform
terraform apply -auto-approve

# Step 7: Output deployment information
echo -e "${GREEN}===================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}===================================${NC}"

FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "N/A")
BACKEND_URL=$(terraform output -raw backend_url 2>/dev/null || echo "N/A")

echo ""
echo -e "${GREEN}Frontend URL:${NC} ${FRONTEND_URL}"
echo -e "${GREEN}Backend URL:${NC} ${BACKEND_URL}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Initialize your database with the schema migrations"
echo "2. Access your application at the frontend URL above"
echo "3. Monitor logs: gcloud logging read 'resource.type=cloud_run_revision' --limit 50"
echo ""

cd ../..
