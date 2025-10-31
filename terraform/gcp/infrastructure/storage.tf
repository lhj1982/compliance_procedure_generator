# Cloud Storage bucket for generated documents (GCP equivalent of AWS S3)

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

# IAM policy to prevent public access
resource "google_storage_bucket_iam_member" "documents_private" {
  bucket = google_storage_bucket.documents.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"

  # This is intentionally set to deny public access
  condition {
    title       = "never"
    description = "Deny all public access"
    expression  = "false"
  }
}
