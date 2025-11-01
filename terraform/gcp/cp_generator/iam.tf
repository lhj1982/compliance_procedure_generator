# ============================================================================
# Service Accounts
# ============================================================================

# Backend service account
resource "google_service_account" "backend" {
  account_id   = "${var.app_name}-backend-${var.environment}"
  display_name = "Compliance Backend Service Account"
  project      = var.project_id
}

# Frontend service account
resource "google_service_account" "frontend" {
  account_id   = "${var.app_name}-frontend-${var.environment}"
  display_name = "Compliance Frontend Service Account"
  project      = var.project_id
}

# Bastion service account
resource "google_service_account" "bastion" {
  account_id   = "${var.app_name}-bastion-${var.environment}"
  display_name = "Bastion Host Service Account"
  project      = var.project_id
}

# ============================================================================
# Secret Manager IAM
# ============================================================================

# Backend - access to application secrets
resource "google_secret_manager_secret_iam_member" "backend_secret_access" {
  project   = var.project_id
  secret_id = var.app_secrets_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.backend.email}"
}

# ============================================================================
# Cloud Storage IAM
# ============================================================================

# Backend - access to documents bucket
resource "google_storage_bucket_iam_member" "backend_storage_access" {
  bucket = var.documents_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.backend.email}"
}
