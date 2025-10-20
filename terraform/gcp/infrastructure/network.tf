# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.app_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Subnet for Cloud Run services (public)
resource "google_compute_subnetwork" "public" {
  name          = "${var.app_name}-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.main.id

  private_ip_google_access = true
}

# Subnet for private services (Cloud SQL, etc.)
resource "google_compute_subnetwork" "private" {
  name          = "${var.app_name}-private-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.main.id

  private_ip_google_access = true
}

# Reserve IP range for VPC peering with Cloud SQL
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.app_name}-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

# VPC Peering for Cloud SQL
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  depends_on = [google_project_service.required_apis]
}

# VPC Access Connector for Cloud Run to access VPC resources
resource "google_vpc_access_connector" "connector" {
  name          = "${var.app_name}-vpc-connector"
  region        = var.region
  network       = google_compute_network.main.name
  ip_cidr_range = "10.8.0.0/28"

  depends_on = [google_project_service.required_apis]
}

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "${var.app_name}-router"
  region  = var.region
  network = google_compute_network.main.id
}

# Cloud NAT for outbound internet access from private instances
resource "google_compute_router_nat" "nat" {
  name                               = "${var.app_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall rules
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.app_name}-allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/16"]
  priority      = 1000
}

resource "google_compute_firewall" "allow_http_https" {
  name    = "${var.app_name}-allow-http-https"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
  priority      = 1000
}
