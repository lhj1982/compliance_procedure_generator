# Compliance Procedure Generator

A web application for generating compliance procedure documents using AI. This project can be deployed to **Google Cloud Platform (GCP)** or **Amazon Web Services (AWS)** with minimal cost configurations, or run locally for development.

## Features

- Team-based compliance form with 15 predefined questions
- AI-powered document generation using OpenAI API
- Multi-cloud deployment support (GCP Cloud Run or AWS ECS Fargate)
- Cloud-native storage (GCS, S3, or local filesystem)
- Document generation with naming convention: `<team_id>_procedure_document.docx`
- Containerized architecture with Docker
- Infrastructure as Code with Terraform

## Deployment Options

### Option 1: Cloud Deployment (Production)

Deploy to GCP or AWS with minimal cost configurations:

- **GCP**: ~$10-25/month (Cloud Run + Cloud SQL + GCS)
- **AWS**: ~$80-90/month (ECS Fargate + RDS + S3 + ALB)

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete deployment instructions.

**Quick Deploy:**

```bash
# GCP
export TF_VAR_llm_api_key="your-api-key"
export TF_VAR_db_password="your-db-password"
./scripts/deploy_gcp.sh your-project-id us-central1

# AWS
export TF_VAR_llm_api_key="your-api-key"
export TF_VAR_db_password="your-db-password"
./scripts/deploy_aws.sh us-east-1
```

### Option 2: Local Development

Run locally with Docker Compose and local database:

## Prerequisites

### For Local Development:
1. **Docker and Docker Compose** installed
2. **OpenAI API key** for document generation
3. **compliance_procedure_admin project** (optional, for database integration)

### For Cloud Deployment:
1. **Terraform** (v1.0+) installed
2. **gcloud CLI** (for GCP) or **AWS CLI** (for AWS)
3. Cloud account with billing enabled
4. See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed prerequisites

## Setup

### 1. Clone and configure environment

```bash
# Copy environment file
cp .env.example .env

# Edit .env file with your OpenAI API credentials
nano .env
```

### 2. Database Schema Migration

Apply the database migration to the existing admin portal database:

```bash
# Connect to the admin portal's PostgreSQL database
psql -h localhost -U postgres -d compliance_admin

# Run the migration script
\i /path/to/compliance_procedure_admin/schema/003_update_procedures_table.sql
```

### 3. Deploy with Docker

```bash
# Build and start the services
docker-compose up --build

# Or run in background
docker-compose up -d --build
```

## Services

- **Backend**: http://localhost:9090 (Flask API)
- **Frontend**: http://localhost:8082 (Nginx + Static files)

## Architecture

### Database Integration
- Uses existing `teams` table from admin portal
- Shared `teams_compliance_procedures` table with unique constraint on `team_id`
- UPSERT logic: subsequent submissions update existing records

### File Storage
- **Local**: Documents saved to admin portal's `backend/generated_docs/` directory
- **GCP**: Documents stored in Google Cloud Storage (GCS)
- **AWS**: Documents stored in Amazon S3
- Automatic storage handler selection based on environment configuration

### Network Configuration
- Connects to external network: `compliance_procedure_admin_compliance_sample`
- Uses existing PostgreSQL container: `compliance_procedure_admin-postgres-1`

## Development

For local development without Docker:

```bash
# Backend (Terminal 1)
cd backend
pip install -r requirements.txt
python server.py
# Backend API will be available at http://localhost:9090

# Frontend (Terminal 2)
cd frontend
npm run dev
# Frontend will be available at http://localhost:8082
```

## API Endpoints

- `GET /api/teams` - Fetch available teams
- `POST /api/submit_answers` - Submit compliance form
- `GET /api/download/<filename>` - Download generated document

## Database Schema

The migration adds to existing `teams_compliance_procedures` table:
- `submission_data` (JSONB) - Stores form answers
- `document_name` (VARCHAR) - Renamed from `file_path`
- `UNIQUE(team_id)` constraint - One document per team

## Cloud Deployment

For deploying to GCP or AWS, see the comprehensive [DEPLOYMENT.md](DEPLOYMENT.md) guide which includes:

- Step-by-step deployment instructions for GCP and AWS
- Cost optimization strategies
- Infrastructure diagrams
- Monitoring and troubleshooting
- Security best practices
- CI/CD setup

**Automated deployment scripts:**
- `./scripts/deploy_gcp.sh` - Deploy to Google Cloud Platform
- `./scripts/deploy_aws.sh` - Deploy to Amazon Web Services

## Project Structure

```
compliance_procedure_generator/
├── backend/              # Flask API backend
│   ├── storage_handler.py  # Multi-cloud storage (GCS/S3/Local)
│   └── server.py
├── frontend/             # Static frontend
├── terraform/
│   ├── gcp/             # GCP infrastructure
│   └── aws/             # AWS infrastructure
├── scripts/
│   ├── deploy_gcp.sh    # GCP deployment automation
│   └── deploy_aws.sh    # AWS deployment automation
├── DEPLOYMENT.md        # Comprehensive deployment guide
└── docker-compose.yml   # Local development
```

## Environment Variables

The application supports multiple storage backends:

```bash
# LLM Configuration
LLM_API_KEY=your-api-key
LLM_BASE_URL=https://api.openai.com/v1

# Database
DB_HOST=localhost
DB_NAME=compliance_admin
DB_USER=postgres
DB_PASSWORD=password

# Storage (choose one)
USE_GCS=true              # For Google Cloud Storage
GCS_BUCKET_NAME=bucket

USE_S3=true               # For Amazon S3
S3_BUCKET_NAME=bucket
AWS_REGION=us-east-1

# Default: Local filesystem
ADMIN_DOCS_PATH=/path/to/docs
```

## Troubleshooting

### Local Development:
1. **Database connection issues**: Ensure admin portal PostgreSQL is running
2. **Network issues**: Verify external network exists: `docker network ls`
3. **File permission issues**: Check mounted volume permissions
4. **API errors**: Verify OpenAI API key and credits

### Cloud Deployments:
See the [DEPLOYMENT.md](DEPLOYMENT.md) troubleshooting section for:
- GCP Cloud Run issues
- AWS ECS/Fargate issues
- Database connectivity problems
- Storage access errors
- Monitoring and logging

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with `docker-compose up`
5. Submit a pull request

## License

[Your License Here]

## Support

For deployment issues, see [DEPLOYMENT.md](DEPLOYMENT.md)
For general questions, open an issue on GitHub