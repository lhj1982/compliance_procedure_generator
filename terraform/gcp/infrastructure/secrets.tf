# Secret Manager for sensitive data (GCP equivalent of AWS Secrets Manager)

# Combined secret for LLM API Key and DB password
resource "google_secret_manager_secret" "cp_gen_secrets" {
  secret_id = "${var.app_name}-gen-secrets-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    name        = "${var.app_name}-gen-secrets"
    environment = var.environment
  }
}

# Note: The actual secret value should be set via:
# gcloud secrets versions add SECRET_NAME --data-file=- <<EOF
# {
#   "llm_api_key": "your-key",
#   "db_password": "your-password"
# }
# EOF

# Or you can create separate secrets for each value:
resource "google_secret_manager_secret" "llm_api_key" {
  secret_id = "${var.app_name}-llm-api-key-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    name        = "${var.app_name}-llm-api-key"
    environment = var.environment
  }
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.app_name}-db-password-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    name        = "${var.app_name}-db-password"
    environment = var.environment
  }
}

# Secret versions - only create if values are provided
resource "google_secret_manager_secret_version" "llm_api_key" {
  count = var.llm_api_key != "" ? 1 : 0

  secret      = google_secret_manager_secret.llm_api_key.id
  secret_data = var.llm_api_key
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}
