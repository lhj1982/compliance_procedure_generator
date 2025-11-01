# Compliance Procedure Generator

A web application for generating compliance procedure documents using AI (LLM). This project can be deployed to **Google Cloud Platform (GCP)** or **Amazon Web Services (AWS)**, or run locally for development.

## Features

- Team-based compliance questionnaire (customizable questions per team)
- AI-powered document generation using LLM API (OpenAI-compatible)
- Multi-cloud deployment support (GCP Cloud Run or AWS ECS Fargate)
- Cloud-native storage (Google Cloud Storage or Amazon S3)
- PostgreSQL database for team management and submission tracking
- Containerized architecture with separate frontend and backend services
- Infrastructure as Code with Terraform

## Architecture Overview

### Components

- **Frontend**: Static HTML/CSS/JS files served by nginx
  - Browser-based application
  - Calls backend API directly via AJAX

- **Backend**: Python Flask API
  - Handles API requests
  - Integrates with LLM for document generation
  - Manages database and cloud storage operations

- **Database**: PostgreSQL
  - Stores team information and questions
  - Tracks compliance procedure submissions

- **Storage**: Cloud Storage (GCS or S3)
  - Stores generated compliance documents

## Deployment Options

### 1. Google Cloud Platform (Recommended for Cost)

**Estimated Cost**: ~$17-38/month for development

**Services Used**:
- Cloud Run (serverless containers)
- Cloud SQL (PostgreSQL)
- Cloud Storage
- Secret Manager
- VPC with private networking

**Architecture**: Browser-direct API with CORS protection
- Frontend serves static files
- Browser calls backend API directly
- Backend is CORS-protected (only accepts `*.run.app` origins)

**Documentation**:
- [GCP Architecture](terraform/gcp/ARCHITECTURE.md) - Detailed architecture overview
- [GCP Deployment Guide](terraform/gcp/DEPLOYMENT.md) - Step-by-step deployment
- [GCP Secrets Management](terraform/gcp/SECRETS.md) - Secret configuration
- [GCP Testing Guide](terraform/gcp/TESTING.md) - Testing and verification

**Quick Start**:
```bash
cd terraform/gcp
# See DEPLOYMENT.md for complete instructions
```

### 2. Amazon Web Services

**Estimated Cost**: ~$80-90/month

**Services Used**:
- ECS Fargate (containerized services)
- RDS PostgreSQL
- S3 (storage)
- Application Load Balancer
- VPC with public/private subnets

**Architecture**: ALB-based routing
- ALB routes traffic to frontend and backend services
- Backend is in private subnet
- Frontend proxies API requests to backend

**Documentation**:
- [AWS README](terraform/aws/README.md) - AWS-specific information

**Quick Start**:
```bash
cd terraform/aws
# See AWS README for instructions
```

### 3. Local Development

Run locally with Docker Compose:

```bash
docker-compose up --build
```

Services will be available at:
- Frontend: http://localhost:8082
- Backend API: http://localhost:9090

## Quick Deployment Comparison

| Feature | GCP | AWS |
|---------|-----|-----|
| **Monthly Cost** | $17-38 | $80-90 |
| **Compute** | Cloud Run (serverless) | ECS Fargate |
| **Database** | Cloud SQL | RDS PostgreSQL |
| **Storage** | Google Cloud Storage | Amazon S3 |
| **Networking** | VPC with Cloud Run | VPC with ALB |
| **Scaling** | Auto (0-10 instances) | Auto (0-10 tasks) |
| **Cold Start** | ~2-3 seconds | ~10-15 seconds |
| **Best For** | Cost-effective, simple | Enterprise, existing AWS |

## Key Differences

### GCP Approach (Simpler, Cheaper)
- **No load balancer** - Cloud Run provides HTTPS endpoints
- **CORS-based security** - Backend accepts only `*.run.app` origins
- **Browser-direct API** - Frontend JavaScript calls backend URL directly
- **Serverless compute** - Pay only for actual usage
- **Cost**: ~$18-25/month savings by avoiding load balancer

### AWS Approach (Traditional)
- **Application Load Balancer** - Routes traffic to services
- **Private backend** - Not directly accessible from internet
- **Frontend proxy** - Nginx proxies `/api/*` to backend
- **ECS Fargate** - Container-based compute with minimum pricing
- **Cost**: Higher due to ALB (~$16/month) and Fargate minimums

## Prerequisites

### For GCP Deployment:
- Google Cloud Project with billing enabled
- gcloud CLI installed and authenticated
- Terraform v1.0+ installed
- Docker installed (for building images)
- LLM API key (OpenAI or compatible)

### For AWS Deployment:
- AWS Account with appropriate permissions
- AWS CLI installed and configured
- Terraform v1.0+ installed
- Docker installed
- LLM API key (OpenAI or compatible)

### For Local Development:
- Docker and Docker Compose installed
- LLM API key
- (Optional) Existing PostgreSQL database

## Project Structure

```
compliance_procedure_generator/
├── backend/                    # Python Flask API
│   ├── server.py              # Main API server
│   ├── storage_handler.py     # Multi-cloud storage abstraction
│   ├── Dockerfile.gcp         # GCP-specific Docker build
│   └── requirements.txt
├── frontend/                   # Static web application
│   ├── index.html
│   ├── static/
│   │   ├── app.js             # Frontend JavaScript
│   │   ├── config.js          # Backend URL configuration (GCP)
│   │   └── style.css
│   └── Dockerfile.gcp         # GCP-specific Docker build
├── terraform/
│   ├── gcp/                   # Google Cloud Platform
│   │   ├── infrastructure/    # Base infrastructure (VPC, DB, Storage)
│   │   ├── cp_generator/      # Application deployment (Cloud Run)
│   │   ├── ARCHITECTURE.md    # Architecture documentation
│   │   ├── DEPLOYMENT.md      # Deployment guide
│   │   ├── SECRETS.md         # Secret management guide
│   │   └── TESTING.md         # Testing guide
│   └── aws/                   # Amazon Web Services
│       └── README.md          # AWS deployment guide
├── scripts/
│   └── build_and_push.sh      # Docker build and push script (GCP)
├── docker-compose.yml         # Local development
└── README.md                  # This file
```

## Environment Variables

### Backend Configuration

**Required**:
- `LLM_API_KEY` - API key for LLM service (or via `APP_SECRETS`)
- `LLM_BASE_URL` - LLM API base URL
- `DB_PASSWORD` - Database password (or via `APP_SECRETS`)
- `DB_HOST` - Database host
- `DB_NAME` - Database name
- `DB_USER` - Database user

**Cloud-Specific**:
- `DOCUMENTS_BUCKET` - Cloud storage bucket name
- `GCP_PROJECT_ID` - (GCP only) Project ID
- `NODE_ENV` - Environment (dev/staging/prod)

**GCP Secret Format** (single JSON secret):
```json
{
  "llm_api_key": "your-api-key",
  "db_password": "your-db-password"
}
```

### Frontend Configuration

**GCP Only**:
- Backend URL configured in `static/config.js` at build time
- No environment variables needed at runtime

**AWS**:
- Backend URL passed via ALB routing (no configuration needed)

## API Endpoints

- `GET /` - Health check
- `GET /api/teams` - List all teams
- `GET /api/teams/{id}/questions` - Get questions for a team
- `POST /api/submit_answers` - Submit compliance form and generate document
- `GET /api/download/{filename}` - Download generated document

## Database Schema

### `teams` Table
```sql
CREATE TABLE teams (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    questions JSONB
);
```

### `teams_compliance_procedures` Table
```sql
CREATE TABLE teams_compliance_procedures (
    id SERIAL PRIMARY KEY,
    team_id INTEGER UNIQUE REFERENCES teams(id),
    document_name VARCHAR(255),
    submission_data JSONB,
    status VARCHAR(50),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

## Development Workflow

### 1. Local Development
```bash
# Start services
docker-compose up --build

# Access application
open http://localhost:8082

# View logs
docker-compose logs -f backend
```

### 2. Build and Test
```bash
# Build backend
cd backend
docker build -f Dockerfile.gcp -t backend:test .

# Build frontend
cd frontend
docker build -f Dockerfile.gcp -t frontend:test .

# Test locally
docker run -p 9090:9090 backend:test
docker run -p 8082:8082 frontend:test
```

### 3. Deploy to Cloud

**GCP**:
```bash
cd terraform/gcp
# Follow DEPLOYMENT.md for complete steps
```

**AWS**:
```bash
cd terraform/aws
# Follow AWS README for complete steps
```

## Security

### GCP Security Model
- **Frontend**: Public Cloud Run service (static files only)
- **Backend**: Public with CORS protection (only `*.run.app` origins)
- **Database**: Private IP, VPC-only access
- **Secrets**: Secret Manager with IAM-based access
- **Storage**: Private bucket with IAM-based access
- **Bastion**: No external IP, IAP tunnel only

### AWS Security Model
- **Frontend**: Public ALB access (static files)
- **Backend**: Private subnet, ALB access only
- **Database**: Private subnet, VPC-only access
- **Secrets**: SSM Parameter Store or Secrets Manager
- **Storage**: Private S3 bucket with IAM policies
- **Bastion**: Public subnet with security group restrictions

## Monitoring and Logging

### GCP
```bash
# Frontend logs
gcloud run services logs read cp-frontend-dev --region=europe-north1

# Backend logs
gcloud run services logs read cp-backend-dev --region=europe-north1

# Database logs
gcloud sql operations list --instance=cp-db-dev
```

### AWS
```bash
# ECS service logs (CloudWatch)
aws logs tail /ecs/compliance-backend --follow

# ALB access logs (S3)
aws s3 ls s3://alb-logs-bucket/

# RDS logs
aws rds describe-db-log-files --db-instance-identifier compliance-db
```

## Cost Optimization

### GCP Cost Savings
- Use Cloud Run (scale to zero)
- Use `db-f1-micro` for Cloud SQL in dev
- Use preemptible bastion in dev
- Set `PRIVATE_RANGES_ONLY` egress
- **No load balancer** = Save ~$18-25/month

### AWS Cost Savings
- Use Fargate Spot for non-prod
- Use smallest RDS instance (db.t3.micro)
- Use S3 lifecycle policies
- Use NAT Gateway only in one AZ
- Consider AWS Free Tier for first year

## Troubleshooting

### Common Issues

**GCP**:
- **404 on API calls**: Ensure `config.js` has correct backend URL
- **CORS errors**: Verify backend CORS allows `*.run.app`
- **Permission errors**: Check IAM roles for service accounts
- **First terraform apply fails**: Run `terraform apply` again

**AWS**:
- **504 Gateway Timeout**: Check backend health check endpoint
- **Database connection failed**: Verify security group rules
- **Task fails to start**: Check CloudWatch logs for errors
- **High costs**: Review ALB and Fargate usage

See deployment guides for detailed troubleshooting.

## Documentation

- [GCP Architecture](terraform/gcp/ARCHITECTURE.md) - Detailed GCP design
- [GCP Deployment](terraform/gcp/DEPLOYMENT.md) - Step-by-step GCP deployment
- [GCP Secrets](terraform/gcp/SECRETS.md) - Secret management for GCP
- [GCP Testing](terraform/gcp/TESTING.md) - Testing and verification
- [AWS README](terraform/aws/README.md) - AWS-specific guide
- [AWS vs GCP](terraform/gcp/AWS_VS_GCP.md) - Platform comparison

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test locally with `docker-compose up`
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

[Your License Here]

## Support

- **Issues**: Open an issue on GitHub
- **GCP Deployment**: See [GCP DEPLOYMENT.md](terraform/gcp/DEPLOYMENT.md)
- **AWS Deployment**: See [AWS README](terraform/aws/README.md)
- **General Questions**: Check existing documentation first
