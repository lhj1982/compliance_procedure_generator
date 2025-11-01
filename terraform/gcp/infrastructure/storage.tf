# Cloud Storage bucket for generated documents

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_storage_bucket" "documents" {
  name          = "${var.app_name}-documents-${var.environment}-${data.google_project.current.number}"
  location      = var.region
  project       = var.project_id
  storage_class = "STANDARD"

  # Prevent public access
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Versioning for document history
  versioning {
    enabled = true
  }

  # Lifecycle rules
  lifecycle_rule {
    condition {
      age = 90 # Delete after 90 days
    }
    action {
      type = "Delete"
    }
  }

  # Prevent accidental deletion
  force_destroy = var.environment != "prod"

  labels = {
    name        = "${var.app_name}-documents"
    environment = var.environment
  }
}

# Grant access to Cloud Run service account
resource "google_storage_bucket_iam_member" "service_account_access" {
  bucket = google_storage_bucket.documents.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.service_account_email}"
}
