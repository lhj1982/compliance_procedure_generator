# Artifact Registry for Docker images (GCP equivalent of AWS ECR)

# Repository for generator backend
resource "google_artifact_registry_repository" "gen_backend" {
  location      = var.region
  repository_id = "${var.app_name}-gen-backend"
  description   = "Docker repository for compliance procedure generator backend"
  format        = "DOCKER"
  project       = var.project_id

  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "keep-last-5-images"
    action = "DELETE"
    condition {
      tag_state    = "ANY"
      older_than   = "0s"
      newer_than   = "0s"
      package_name_prefixes = []
    }
    most_recent_versions {
      keep_count = 5
    }
  }

  labels = {
    name        = "${var.app_name}-gen-backend"
    environment = var.environment
  }
}

# Repository for generator frontend
resource "google_artifact_registry_repository" "gen_frontend" {
  location      = var.region
  repository_id = "${var.app_name}-gen-frontend"
  description   = "Docker repository for compliance procedure generator frontend"
  format        = "DOCKER"
  project       = var.project_id

  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "keep-last-5-images"
    action = "DELETE"
    condition {
      tag_state    = "ANY"
      older_than   = "0s"
      newer_than   = "0s"
      package_name_prefixes = []
    }
    most_recent_versions {
      keep_count = 5
    }
  }

  labels = {
    name        = "${var.app_name}-gen-frontend"
    environment = var.environment
  }
}

# Repository for admin backend
resource "google_artifact_registry_repository" "admin_backend" {
  location      = var.region
  repository_id = "${var.app_name}-admin-backend"
  description   = "Docker repository for compliance procedure admin backend"
  format        = "DOCKER"
  project       = var.project_id

  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "keep-last-5-images"
    action = "DELETE"
    condition {
      tag_state    = "ANY"
      older_than   = "0s"
      newer_than   = "0s"
      package_name_prefixes = []
    }
    most_recent_versions {
      keep_count = 5
    }
  }

  labels = {
    name        = "${var.app_name}-admin-backend"
    environment = var.environment
  }
}

# Repository for admin frontend
resource "google_artifact_registry_repository" "admin_frontend" {
  location      = var.region
  repository_id = "${var.app_name}-admin-frontend"
  description   = "Docker repository for compliance procedure admin frontend"
  format        = "DOCKER"
  project       = var.project_id

  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "keep-last-5-images"
    action = "DELETE"
    condition {
      tag_state    = "ANY"
      older_than   = "0s"
      newer_than   = "0s"
      package_name_prefixes = []
    }
    most_recent_versions {
      keep_count = 5
    }
  }

  labels = {
    name        = "${var.app_name}-admin-frontend"
    environment = var.environment
  }
}
