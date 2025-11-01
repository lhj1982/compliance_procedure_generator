# ============================================================================
# Cloud Run Services
# ============================================================================

# Backend Service - API endpoints for compliance procedure generation
resource "google_cloud_run_v2_service" "backend" {
  name     = "${var.app_name}-backend-${var.environment}"
  location = var.region
  project  = var.project_id

  # Allow all traffic - security is enforced via CORS in application code
  # CORS restricts to *.run.app origins only (see backend/server.py)
  # Note: INGRESS_TRAFFIC_INTERNAL_ONLY blocks browser requests
  ingress = "INGRESS_TRAFFIC_ALL"

  # Ensure IAM roles are set before deploying backend
  depends_on = [
    google_secret_manager_secret_iam_member.backend_secret_access,
    google_storage_bucket_iam_member.backend_storage_access
  ]

  template {
    service_account = google_service_account.backend.email

    containers {
      image = var.backend_image

      ports {
        container_port = 9090
      }

      # Database configuration
      env {
        name  = "DB_HOST"
        value = var.db_private_ip
      }

      env {
        name  = "DB_PORT"
        value = "5432"
      }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }

      env {
        name  = "DB_USER"
        value = var.db_user
      }

      # LLM configuration
      env {
        name  = "LLM_BASE_URL"
        value = var.llm_base_url
      }

      # Application secrets from Secret Manager
      # JSON format: {"llm_api_key": "value", "db_password": "value"}
      env {
        name = "APP_SECRETS"
        value_source {
          secret_key_ref {
            secret  = var.app_secrets_id
            version = "latest"
          }
        }
      }

      # Storage configuration
      env {
        name  = "DOCUMENTS_BUCKET"
        value = var.documents_bucket_name
      }

      # Application configuration
      env {
        name  = "NODE_ENV"
        value = var.environment
      }

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = var.environment == "prod" ? 1 : 0
      max_instance_count = var.environment == "prod" ? 10 : 3
    }

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Frontend Service - Static file server (nginx)
resource "google_cloud_run_v2_service" "frontend" {
  name     = "${var.app_name}-frontend-${var.environment}"
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.frontend.email

    containers {
      image = var.frontend_image

      ports {
        container_port = 8082
      }

      # No environment variables needed
      # Backend URL is configured in static/config.js at build time

      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = var.environment == "prod" ? 1 : 0
      max_instance_count = var.environment == "prod" ? 10 : 5
    }

    # No VPC access needed - frontend just serves static files
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# ============================================================================
# Cloud Run IAM Policies
# ============================================================================

# Backend - allow public access (CORS enforces security)
resource "google_cloud_run_v2_service_iam_member" "backend_public" {
  name     = google_cloud_run_v2_service.backend.name
  location = var.region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Frontend - allow public access
resource "google_cloud_run_v2_service_iam_member" "frontend_public" {
  name     = google_cloud_run_v2_service.frontend.name
  location = var.region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}
