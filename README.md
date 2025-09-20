# Compliance Procedure Generator

A web application for generating compliance procedure documents using AI. This project integrates with the existing `compliance_procedure_admin` project, sharing the same database and generated documents directory.

## Features

- Team-based compliance form with 15 predefined questions
- AI-powered document generation using OpenAI API
- Integration with existing teams from admin portal
- Document generation with naming convention: `<team_id>_procedure_document.docx`
- Shared database for tracking submissions

## Prerequisites

1. **compliance_procedure_admin project** must be running with PostgreSQL database
2. **Docker and Docker Compose** installed
3. **OpenAI API key** for document generation

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
- Generated documents saved to admin portal's `backend/generated_docs/` directory
- Shared volume mount ensures both projects can access documents

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

## Troubleshooting

1. **Database connection issues**: Ensure admin portal PostgreSQL is running
2. **Network issues**: Verify external network exists: `docker network ls`
3. **File permission issues**: Check mounted volume permissions
4. **API errors**: Verify OpenAI API key and credits