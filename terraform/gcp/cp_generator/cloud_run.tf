# Backend Service (Private - only accessible via VPC)
resource "google_cloud_run_v2_service" "backend" {
  name     = "${var.app_name}-backend-${var.environment}"
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = var.backend_image

      ports {
        container_port = 9090
      }

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

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "LLM_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.llm_api_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "NODE_ENV"
        value = var.environment
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

  depends_on = [
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_version.llm_api_key
  ]
}

# Frontend Service (Public - serves static files and proxies to backend)
resource "google_cloud_run_v2_service" "frontend" {
  name     = "${var.app_name}-frontend-${var.environment}"
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = var.frontend_image

      ports {
        container_port = 80
      }

      env {
        name  = "BACKEND_URL"
        value = google_cloud_run_v2_service.backend.uri
      }

      env {
        name  = "ADMIN_URL"
        value = google_cloud_run_v2_service.admin.uri
      }

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

# Admin Service (Private - only accessible via VPC)
resource "google_cloud_run_v2_service" "admin" {
  name     = "${var.app_name}-admin-${var.environment}"
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = var.admin_image

      ports {
        container_port = 8081
      }

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

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "NODE_ENV"
        value = var.environment
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
      max_instance_count = var.environment == "prod" ? 5 : 2
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

  depends_on = [google_secret_manager_secret_version.db_password]
}

# IAM policy for backend - allow only VPC and load balancer access
resource "google_cloud_run_v2_service_iam_member" "backend_invoker" {
  name   = google_cloud_run_v2_service.backend.name
  location = var.region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.frontend.email}"
}

# IAM policy for admin - allow only VPC and load balancer access
resource "google_cloud_run_v2_service_iam_member" "admin_invoker" {
  name   = google_cloud_run_v2_service.admin.name
  location = var.region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.frontend.email}"
}

# IAM policy for frontend - allow public access (via load balancer)
resource "google_cloud_run_v2_service_iam_member" "frontend_public" {
  name   = google_cloud_run_v2_service.frontend.name
  location = var.region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Service account for frontend to invoke backend services
resource "google_service_account" "frontend" {
  account_id   = "${var.app_name}-frontend-${var.environment}"
  display_name = "Compliance Frontend Service Account"
  project      = var.project_id
}
