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

# Data sources for infrastructure resources
data "google_sql_database_instance" "postgres" {
  name = var.sql_instance_name
}

data "google_storage_bucket" "documents" {
  name = var.storage_bucket_name
}

data "google_secret_manager_secret" "cp_gen_secrets" {
  secret_id = var.secret_manager_secret_id
}

data "google_service_account" "cloud_run" {
  account_id = var.service_account_email
}

# Backend Cloud Run Service (private)
resource "google_cloud_run_v2_service" "backend" {
  name     = "${var.app_name}-backend"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = data.google_service_account.cloud_run.email

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.gen_backend_registry_name}/backend:latest"
      
      ports {
        container_port = 9090
      }

      env {
        name  = "DB_HOST"
        value = data.google_sql_database_instance.postgres.private_ip_address
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_NAME"
        value = var.database_name
      }
      env {
        name  = "DB_USER"
        value = "postgres"
      }
      env {
        name = "DB_PASSWORD"
        value = "postgres"
      }
      env {
        name  = "LLM_BASE_URL"
        value = var.llm_base_url
      }
      env {
        name = "LLM_API_KEY"
        value_source {
          secret_key_ref {
            secret  = data.google_secret_manager_secret.cp_gen_secrets.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "USE_GCS"
        value = "true"
      }
      env {
        name  = "GCS_BUCKET_NAME"
        value = data.google_storage_bucket.documents.name
      }
    }

    vpc_access {
      connector = "projects/${var.project_id}/locations/${var.region}/connectors/${var.vpc_connector_name}"
      egress    = "PRIVATE_RANGES_ONLY"
    }
  }
}

# Frontend Cloud Run Service (public)
resource "google_cloud_run_v2_service" "frontend" {
  name     = "${var.app_name}-frontend"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = data.google_service_account.cloud_run.email

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.gen_frontend_registry_name}/frontend:latest"
      
      ports {
        container_port = 8082
      }

      env {
        name  = "BACKEND_URL"
        value = google_cloud_run_v2_service.backend.uri
      }

      # Add OIDC token environment variable
      env {
        name  = "OIDC_TOKEN"
        value = "$(/usr/bin/curl -H 'Metadata-Flavor: Google' http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/identity?audience=${google_cloud_run_v2_service.backend.uri})"
      }
    }
  }
}

# IAM: Allow public access to frontend
resource "google_cloud_run_v2_service_iam_member" "frontend_public" {
  location = var.region
  name     = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# IAM: Allow frontend to access backend
resource "google_cloud_run_v2_service_iam_member" "frontend_to_backend" {
  location = var.region
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${data.google_service_account.cloud_run.email}"
}

# IAM: Allow bastion to access backend
resource "google_cloud_run_v2_service_iam_member" "bastion_to_backend" {
  location = var.region
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.bastion.email}"
}
