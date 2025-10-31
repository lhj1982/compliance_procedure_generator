# Reserve a static external IP address for the load balancer
resource "google_compute_global_address" "default" {
  name    = "compliance-lb-ip-${var.environment}"
  project = var.project_id
}

# Backend service for Cloud Run frontend
resource "google_compute_region_network_endpoint_group" "frontend_neg" {
  name                  = "compliance-frontend-neg-${var.environment}"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  project               = var.project_id

  cloud_run {
    service = google_cloud_run_v2_service.frontend.name
  }
}

resource "google_compute_backend_service" "frontend" {
  name        = "compliance-frontend-backend-${var.environment}"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  project     = var.project_id

  backend {
    group = google_compute_region_network_endpoint_group.frontend_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL map for routing
resource "google_compute_url_map" "default" {
  name            = "compliance-url-map-${var.environment}"
  default_service = google_compute_backend_service.frontend.id
  project         = var.project_id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.frontend.id

    # All paths go to frontend, which will proxy /api/* to backend via nginx
    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_service.frontend.id
    }
  }
}

# HTTP proxy
resource "google_compute_target_http_proxy" "default" {
  name    = "compliance-http-proxy-${var.environment}"
  url_map = google_compute_url_map.default.id
  project = var.project_id
}

# Global forwarding rule (HTTP)
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "compliance-http-lb-${var.environment}"
  target                = google_compute_target_http_proxy.default.id
  port_range            = "80"
  ip_address            = google_compute_global_address.default.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  project               = var.project_id
}

# SSL Certificate (optional, for HTTPS)
# Uncomment and configure if you have a domain
# resource "google_compute_managed_ssl_certificate" "default" {
#   name    = "compliance-ssl-cert-${var.environment}"
#   project = var.project_id
#
#   managed {
#     domains = ["your-domain.com"]
#   }
# }

# HTTPS proxy (optional)
# resource "google_compute_target_https_proxy" "default" {
#   name             = "compliance-https-proxy-${var.environment}"
#   url_map          = google_compute_url_map.default.id
#   ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
#   project          = var.project_id
# }

# Global forwarding rule (HTTPS - optional)
# resource "google_compute_global_forwarding_rule" "https" {
#   name                  = "compliance-https-lb-${var.environment}"
#   target                = google_compute_target_https_proxy.default.id
#   port_range            = "443"
#   ip_address            = google_compute_global_address.default.address
#   load_balancing_scheme = "EXTERNAL_MANAGED"
#   project               = var.project_id
# }
