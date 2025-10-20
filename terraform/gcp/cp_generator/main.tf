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

# Data source to get infrastructure outputs
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

# Backend Cloud Run Service (internal only)
resource "google_cloud_run_v2_service" "backend" {
  name     = "${var.app_name}-backend"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = data.google_service_account.cloud_run.email

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    vpc_access {
      connector = var.vpc_connector_name
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.gen_backend_registry_name}/backend:latest"

      ports {
        container_port = 9090
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
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
        value_source {
          secret_key_ref {
            secret  = data.google_secret_manager_secret.cp_gen_secrets.secret_id
            version = "latest"
          }
        }
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

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }

      # Health check configuration
      startup_probe {
        http_get {
          path = "/"
          port = 9090
        }
        initial_delay_seconds = 10
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/"
          port = 9090
        }
        initial_delay_seconds = 30
        timeout_seconds       = 5
        period_seconds        = 30
        failure_threshold     = 3
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = {
    app         = var.app_name
    environment = var.environment
    component   = "backend"
  }
}

# Frontend Cloud Run Service (public)
resource "google_cloud_run_v2_service" "frontend" {
  name     = "${var.app_name}-frontend"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = data.google_service_account.cloud_run.email

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    vpc_access {
      connector = var.vpc_connector_name
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.gen_frontend_registry_name}/frontend:latest"

      ports {
        container_port = 8082
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      env {
        name  = "BACKEND_INTERNAL_URL"
        value = google_cloud_run_v2_service.backend.uri
      }

      # Health check configuration
      startup_probe {
        http_get {
          path = "/"
          port = 8082
        }
        initial_delay_seconds = 10
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/"
          port = 8082
        }
        initial_delay_seconds = 30
        timeout_seconds       = 5
        period_seconds        = 30
        failure_threshold     = 3
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = {
    app         = var.app_name
    environment = var.environment
    component   = "frontend"
  }
}

# IAM policy to allow public access to frontend
resource "google_cloud_run_service_iam_member" "frontend_public" {
  location = google_cloud_run_v2_service.frontend.location
  service  = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# IAM policy to allow frontend to invoke backend
resource "google_cloud_run_service_iam_member" "frontend_to_backend" {
  location = google_cloud_run_v2_service.backend.location
  service  = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${data.google_service_account.cloud_run.email}"
}

# Load Balancer for backend (internal)
resource "google_compute_region_network_endpoint_group" "backend_neg" {
  name                  = "${var.app_name}-backend-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.backend.name
  }
}

resource "google_compute_region_backend_service" "backend" {
  name                  = "${var.app_name}-backend-backend-service"
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = 120

  backend {
    group           = google_compute_region_network_endpoint_group.backend_neg.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_check = google_compute_region_health_check.backend.id
}

resource "google_compute_region_health_check" "backend" {
  name   = "${var.app_name}-backend-health-check"
  region = var.region

  http_health_check {
    port         = 9090
    request_path = "/"
  }

  check_interval_sec  = 30
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
}

# Load Balancer for frontend (external)
resource "google_compute_region_network_endpoint_group" "frontend_neg" {
  name                  = "${var.app_name}-frontend-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.frontend.name
  }
}

resource "google_compute_region_backend_service" "frontend" {
  name                  = "${var.app_name}-frontend-backend-service"
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 120

  backend {
    group           = google_compute_region_network_endpoint_group.frontend_neg.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_check = google_compute_region_health_check.frontend.id
}

resource "google_compute_region_health_check" "frontend" {
  name   = "${var.app_name}-frontend-health-check"
  region = var.region

  http_health_check {
    port         = 8082
    request_path = "/"
  }

  check_interval_sec  = 30
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
}

# URL Map for frontend
resource "google_compute_region_url_map" "frontend" {
  name            = "${var.app_name}-frontend-url-map"
  region          = var.region
  default_service = google_compute_region_backend_service.frontend.id
}

# HTTP Proxy for frontend
resource "google_compute_region_target_http_proxy" "frontend" {
  name    = "${var.app_name}-frontend-http-proxy"
  region  = var.region
  url_map = google_compute_region_url_map.frontend.id
}

# Forwarding rule for frontend (external)
resource "google_compute_forwarding_rule" "frontend" {
  name                  = "${var.app_name}-frontend-forwarding-rule"
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.frontend.id
}
