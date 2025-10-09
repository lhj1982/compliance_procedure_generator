#!/bin/bash
set -e

# AWS Deployment Script for Compliance Procedure Generator
# Usage: ./scripts/deploy_aws.sh [region]

REGION=${1:-"us-east-1"}
APP_NAME="compliance-procedure-gen"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}===================================${NC}"
echo -e "${GREEN}AWS Deployment Script${NC}"
echo -e "${GREEN}===================================${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install from: https://aws.amazon.com/cli/"
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

# Get AWS Account ID
echo -e "${GREEN}Getting AWS Account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Unable to get AWS Account ID. Please configure AWS CLI.${NC}"
    echo "Run: aws configure"
    exit 1
fi

echo -e "${YELLOW}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"
echo -e "${YELLOW}Region: ${REGION}${NC}"
echo ""

# Step 1: Deploy infrastructure with Terraform (creates ECR repos)
echo -e "${GREEN}Step 1: Deploying infrastructure with Terraform...${NC}"
cd terraform/aws

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    terraform init
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Warning: terraform.tfvars not found. Creating from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${RED}Please edit terraform/aws/terraform.tfvars with your configuration${NC}"
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

# Get ECR repository URLs from Terraform output
BACKEND_REPO=$(terraform output -raw ecr_backend_repository_url 2>/dev/null)
FRONTEND_REPO=$(terraform output -raw ecr_frontend_repository_url 2>/dev/null)

cd ../..

# Step 2: Authenticate Docker with ECR
echo -e "${GREEN}Step 2: Authenticating Docker with ECR...${NC}"
aws ecr get-login-password --region ${REGION} | \
    docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Step 3: Build Docker images
echo -e "${GREEN}Step 3: Building Docker images...${NC}"

echo "Building backend image..."
docker build -t ${BACKEND_REPO}:latest ./backend

echo "Building frontend image..."
docker build -t ${FRONTEND_REPO}:latest ./frontend

# Step 4: Push Docker images to ECR
echo -e "${GREEN}Step 4: Pushing Docker images to ECR...${NC}"

echo "Pushing backend image..."
docker push ${BACKEND_REPO}:latest

echo "Pushing frontend image..."
docker push ${FRONTEND_REPO}:latest

# Step 5: Update ECS services
echo -e "${GREEN}Step 5: Updating ECS services...${NC}"

CLUSTER_NAME="${APP_NAME}-cluster"
BACKEND_SERVICE="${APP_NAME}-backend-service"
FRONTEND_SERVICE="${APP_NAME}-frontend-service"

echo "Updating backend service..."
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${BACKEND_SERVICE} \
    --force-new-deployment \
    --region ${REGION} \
    > /dev/null

echo "Updating frontend service..."
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${FRONTEND_SERVICE} \
    --force-new-deployment \
    --region ${REGION} \
    > /dev/null

# Step 6: Wait for services to stabilize
echo -e "${GREEN}Step 6: Waiting for services to stabilize...${NC}"
echo "This may take a few minutes..."

aws ecs wait services-stable \
    --cluster ${CLUSTER_NAME} \
    --services ${BACKEND_SERVICE} ${FRONTEND_SERVICE} \
    --region ${REGION}

# Step 7: Output deployment information
echo -e "${GREEN}===================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}===================================${NC}"

cd terraform/aws
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")
FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "N/A")
BACKEND_URL=$(terraform output -raw backend_url 2>/dev/null || echo "N/A")
cd ../..

echo ""
echo -e "${GREEN}Application Load Balancer:${NC} ${ALB_DNS}"
echo -e "${GREEN}Frontend URL:${NC} ${FRONTEND_URL}"
echo -e "${GREEN}Backend URL:${NC} ${BACKEND_URL}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Initialize your database with the schema migrations"
echo "2. Access your application at: http://${ALB_DNS}"
echo "3. Monitor ECS services:"
echo "   aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${BACKEND_SERVICE} ${FRONTEND_SERVICE}"
echo "4. View logs:"
echo "   aws logs tail /ecs/${APP_NAME}/backend --follow"
echo "   aws logs tail /ecs/${APP_NAME}/frontend --follow"
echo ""
