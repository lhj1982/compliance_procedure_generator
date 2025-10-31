#!/bin/bash
set -e

# Initialize database with schema
# Run this script on the bastion host

DB_CONNECTION_NAME=${1}
DB_NAME=${2:-compliance_db}
DB_USER=${3:-compliance_user}

if [ -z "$DB_CONNECTION_NAME" ]; then
    echo "Error: Database connection name required"
    echo "Usage: $0 <db-connection-name> [db-name] [db-user]"
    echo "Example: $0 my-project:us-central1:compliance-db-dev"
    exit 1
fi

echo "Starting Cloud SQL Proxy..."
cloud_sql_proxy -instances=$DB_CONNECTION_NAME=tcp:5432 &
PROXY_PID=$!

# Wait for proxy to start
sleep 5

echo "Checking if schema files exist in /tmp..."
if [ ! -f "/tmp/001_initial_schema.sql" ]; then
    echo "Error: Schema files not found in /tmp"
    echo "Please upload schema files first using:"
    echo "  gcloud compute scp compliance_procedure_admin/schema/*.sql BASTION_NAME:/tmp/ --zone=ZONE --tunnel-through-iap"
    kill $PROXY_PID
    exit 1
fi

echo "Applying database schema..."
for file in /tmp/*.sql; do
    echo "Running $file..."
    PGPASSWORD=$DB_PASSWORD psql -h 127.0.0.1 -U $DB_USER -d $DB_NAME -f $file
done

echo "Database initialization complete!"
kill $PROXY_PID
