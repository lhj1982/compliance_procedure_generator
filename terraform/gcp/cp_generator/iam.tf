# IAM permissions for Cloud Run services to access secrets and storage

# Service account for backend service
resource "google_service_account" "backend" {
  account_id   = "${var.app_name}-backend-${var.environment}"
  display_name = "Compliance Backend Service Account"
  project      = var.project_id
}

# Grant backend service account access to Secret Manager
resource "google_secret_manager_secret_iam_member" "backend_secret_access" {
  project   = var.project_id
  secret_id = var.app_secrets_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.backend.email}"
}

# Grant backend service account access to Cloud Storage
resource "google_storage_bucket_iam_member" "backend_storage_access" {
  bucket = var.documents_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.backend.email}"
}

# Service account for frontend service (already exists in cloud_run.tf)
# Grant frontend service account access to secrets (if needed in future)
resource "google_secret_manager_secret_iam_member" "frontend_secret_access" {
  project   = var.project_id
  secret_id = var.app_secrets_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.frontend.email}"
}
