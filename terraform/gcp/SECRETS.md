# Secret Manager Configuration

## Overview

The GCP deployment uses **Google Secret Manager** to securely store sensitive configuration values. We use a **single secret with JSON structure** containing multiple key-value pairs, following best practices for secret management.

## Secret Structure

### Single Combined Secret

**Secret ID**: `{app_name}-secrets-{environment}`

**Format**: JSON with the following structure:
```json
{
  "llm_api_key": "your-llm-api-key-here",
  "db_password": "your-database-password-here"
}
```

### Why Single Secret?

Using a single JSON secret instead of multiple individual secrets provides:

- **Atomic updates**: Update all related secrets in one operation
- **Simpler management**: One secret to manage instead of many
- **Cost efficiency**: Fewer secret versions to maintain
- **Easier rotation**: Rotate all secrets together with confidence
- **Better organization**: Related secrets grouped logically

## Infrastructure Configuration

### Terraform Definition

Located in `infrastructure/secrets.tf`:

```hcl
resource "google_secret_manager_secret" "app_secrets" {
  secret_id = "${var.app_name}-secrets-${var.environment}"

  replication {
    auto {}  # Replicate across all regions
  }
}

resource "google_secret_manager_secret_version" "app_secrets" {
  secret = google_secret_manager_secret.app_secrets.id

  secret_data = jsonencode({
    llm_api_key = var.llm_api_key
    db_password = var.db_password
  })
}
```

## Cloud Run Integration

### Service Accounts

Each Cloud Run service has its own service account:

1. **Backend Service Account**: `{app_name}-backend-{environment}`
   - Has `roles/secretmanager.secretAccessor` on app secrets
   - Has `roles/storage.objectAdmin` on documents bucket

2. **Frontend Service Account**: `{app_name}-frontend-{environment}`
   - Has `roles/run.invoker` on backend service
   - Has `roles/secretmanager.secretAccessor` on app secrets (for future use)

### IAM Permissions

Defined in `cp_generator/iam.tf`:

```hcl
# Grant backend access to secrets
resource "google_secret_manager_secret_iam_member" "backend_secret_access" {
  secret_id = var.app_secrets_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.backend.email}"
}
```

### Environment Variables

The backend Cloud Run service receives the secret as an environment variable:

```hcl
env {
  name = "APP_SECRETS"
  value_source {
    secret_key_ref {
      secret  = var.app_secrets_id
      version = "latest"
    }
  }
}
```

**Important**: Cloud Run injects the **entire secret value** (the JSON string) into the `APP_SECRETS` environment variable. The backend application must parse this JSON to extract individual values.

## Application Integration

### Backend Code Example (Python)

```python
import os
import json

# Parse secrets from environment variable
app_secrets = json.loads(os.environ.get('APP_SECRETS', '{}'))

# Extract individual values
llm_api_key = app_secrets.get('llm_api_key')
db_password = app_secrets.get('db_password')

# Use in your application
# Note: You also have DB_USER, DB_HOST, DB_NAME, DB_PORT from separate env vars
```

### Backend Code Example (Node.js)

```javascript
// Parse secrets from environment variable
const appSecrets = JSON.parse(process.env.APP_SECRETS || '{}');

// Extract individual values
const llmApiKey = appSecrets.llm_api_key;
const dbPassword = appSecrets.db_password;

// Use in your application
```

## Managing Secrets

### Initial Setup (via Terraform)

Secrets are created automatically when you run `terraform apply` with values from `terraform.tfvars`:

```hcl
llm_api_key = "your-actual-llm-api-key"
db_password = "your-strong-database-password"
```

### Updating Secrets After Deployment

#### Option 1: Using gcloud CLI

```bash
# Create new version with updated values
echo '{
  "llm_api_key": "new-llm-key",
  "db_password": "new-db-password"
}' | gcloud secrets versions add compliance-procedure-secrets-dev --data-file=-
```

#### Option 2: Using GCP Console

1. Go to **Security** > **Secret Manager**
2. Find your secret: `compliance-procedure-secrets-dev`
3. Click **New Version**
4. Paste JSON with updated values:
   ```json
   {
     "llm_api_key": "new-llm-key",
     "db_password": "new-db-password"
   }
   ```
5. Click **Add New Version**

#### Option 3: Using Terraform (Re-apply)

Update `terraform.tfvars` and run:
```bash
terraform apply
```

**Note**: This creates a new secret version. Cloud Run services using `version = "latest"` will automatically use the new version on next cold start.

### Secret Rotation

To rotate secrets:

1. **Update Secret Manager** with new values (using any method above)
2. **Restart Cloud Run services** to pick up new values:
   ```bash
   gcloud run services update compliance-procedure-backend-dev --region=us-central1
   gcloud run services update compliance-procedure-frontend-dev --region=us-central1
   ```

Or simply wait for next cold start (services will use new secrets automatically).

## Security Best Practices

### ✅ DO:
- Use strong, randomly generated passwords
- Rotate secrets regularly (every 90 days recommended)
- Use different secrets for each environment (dev, staging, prod)
- Limit IAM permissions to only services that need access
- Monitor secret access via Cloud Logging

### ❌ DON'T:
- Commit secrets to version control
- Share secrets via email or chat
- Use the same secrets across environments
- Grant overly broad IAM permissions
- Store secrets in application code

## Viewing Secret Access Logs

To see which services accessed secrets:

```bash
gcloud logging read "resource.type=secretmanager.googleapis.com/Secret" \
  --limit 50 \
  --format json
```

## Troubleshooting

### Cloud Run can't access secret

**Error**: `Permission denied on secret`

**Solutions**:
1. Verify service account has `secretAccessor` role:
   ```bash
   gcloud secrets get-iam-policy compliance-procedure-secrets-dev
   ```
2. Check Cloud Run service is using correct service account:
   ```bash
   gcloud run services describe compliance-procedure-backend-dev --region=us-central1
   ```

### Backend can't parse secret

**Error**: `JSON decode error` or `KeyError`

**Solutions**:
1. Verify secret format is valid JSON:
   ```bash
   gcloud secrets versions access latest --secret=compliance-procedure-secrets-dev
   ```
2. Check environment variable is being injected:
   ```bash
   # SSH into a running instance or check logs
   ```

### Secret not updating

**Issue**: Changed secret but app still uses old value

**Solutions**:
1. Verify you created a new version (not edited existing):
   ```bash
   gcloud secrets versions list compliance-procedure-secrets-dev
   ```
2. Force Cloud Run to restart:
   ```bash
   gcloud run services update compliance-procedure-backend-dev --region=us-central1
   ```

## Environment Variables Summary

### Backend Service Environment Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `APP_SECRETS` | Secret Manager | JSON containing `llm_api_key` and `db_password` |
| `DB_HOST` | Terraform variable | Cloud SQL private IP |
| `DB_PORT` | Terraform variable | PostgreSQL port (5432) |
| `DB_NAME` | Terraform variable | Database name |
| `DB_USER` | Terraform variable | Database username |
| `DOCUMENTS_BUCKET` | Terraform variable | Cloud Storage bucket name |
| `NODE_ENV` | Terraform variable | Environment (dev/staging/prod) |
| `GCP_PROJECT_ID` | Terraform variable | GCP project ID |

## Adding New Secrets

To add new secret keys to the JSON:

1. **Update `infrastructure/secrets.tf`**:
   ```hcl
   secret_data = jsonencode({
     llm_api_key = var.llm_api_key
     db_password = var.db_password
     new_secret  = var.new_secret  # Add new secret
   })
   ```

2. **Add variable to `infrastructure/variables.tf`**:
   ```hcl
   variable "new_secret" {
     description = "Description of new secret"
     type        = string
     sensitive   = true
   }
   ```

3. **Update `terraform.tfvars`**:
   ```hcl
   new_secret = "new-secret-value"
   ```

4. **Apply changes**:
   ```bash
   terraform apply
   ```

5. **Update backend code** to parse new key from `APP_SECRETS` JSON.
