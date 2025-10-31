# Secret Manager for sensitive data (GCP equivalent of AWS Secrets Manager)
# Using a single secret with JSON structure containing multiple key-value pairs

resource "google_secret_manager_secret" "app_secrets" {
  secret_id = "${var.app_name}-secrets-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    name        = "${var.app_name}-secrets"
    environment = var.environment
  }
}

# Create secret version with JSON structure containing all secrets
# Format: {"llm_api_key": "value", "db_password": "value"}
resource "google_secret_manager_secret_version" "app_secrets" {
  secret = google_secret_manager_secret.app_secrets.id

  secret_data = jsonencode({
    llm_api_key = var.llm_api_key
    db_password = var.db_password
  })
}

# Note: To update secrets after deployment, use:
# echo '{"llm_api_key":"your-new-key","db_password":"your-new-password"}' | \
#   gcloud secrets versions add ${var.app_name}-secrets-${var.environment} --data-file=-
#
# Or use the GCP Console to add a new version with the JSON structure
