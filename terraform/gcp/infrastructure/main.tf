terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "vpcaccess.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "postgres" {
  name             = "${var.app_name}-db-${var.environment}"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = 20

    backup_configuration {
      enabled            = true
      start_time         = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
      require_ssl     = true
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  deletion_protection = false

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_project_service.required_apis
  ]
}

resource "google_sql_database" "compliance_admin" {
  name     = "compliance_admin"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "postgres" {
  name     = "postgres"
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}

# Cloud Storage Bucket for documents
resource "google_storage_bucket" "documents" {
  name          = "${var.project_id}-${var.app_name}-documents-${var.environment}"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  labels = {
    app         = var.app_name
    environment = var.environment
  }
}

# Secret Manager for LLM API Key and DB Password
resource "google_secret_manager_secret" "cp_gen_secrets" {
  secret_id = "${var.app_name}-gen-secrets-${var.environment}"

  replication {
    auto {}
  }

  labels = {
    app         = var.app_name
    environment = var.environment
  }

  depends_on = [google_project_service.required_apis]
}

# You'll need to manually add the secret version with actual values
# Or use terraform to set it if you have the values
resource "google_secret_manager_secret_version" "cp_gen_secrets" {
  secret = google_secret_manager_secret.cp_gen_secrets.id

  secret_data = jsonencode({
    db_password = var.db_password
    api_key     = var.llm_api_key
  })
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "gen_backend" {
  repository_id = "${var.app_name}-gen-backend"
  description   = "Docker repository for ${var.app_name} generator backend"
  format        = "DOCKER"
  location      = var.region

  labels = {
    app         = var.app_name
    environment = var.environment
    component   = "backend"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_artifact_registry_repository" "gen_frontend" {
  repository_id = "${var.app_name}-gen-frontend"
  description   = "Docker repository for ${var.app_name} generator frontend"
  format        = "DOCKER"
  location      = var.region

  labels = {
    app         = var.app_name
    environment = var.environment
    component   = "frontend"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_artifact_registry_repository" "admin_backend" {
  repository_id = "${var.app_name}-admin-backend"
  description   = "Docker repository for ${var.app_name} admin backend"
  format        = "DOCKER"
  location      = var.region

  labels = {
    app         = var.app_name
    environment = var.environment
    component   = "backend"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_artifact_registry_repository" "admin_frontend" {
  repository_id = "${var.app_name}-admin-frontend"
  description   = "Docker repository for ${var.app_name} admin frontend"
  format        = "DOCKER"
  location      = var.region

  labels = {
    app         = var.app_name
    environment = var.environment
    component   = "frontend"
  }

  depends_on = [google_project_service.required_apis]
}

# Service Account for Cloud Run services
resource "google_service_account" "cloud_run" {
  account_id   = "${var.app_name}-cloud-run-sa"
  display_name = "Service Account for Cloud Run services"
  description  = "Used by Cloud Run services to access GCP resources"
}

# Grant permissions to the service account
resource "google_project_iam_member" "cloud_run_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_storage_bucket_iam_member" "cloud_run_storage" {
  bucket = google_storage_bucket.documents.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_secrets" {
  secret_id = google_secret_manager_secret.cp_gen_secrets.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run.email}"
}
