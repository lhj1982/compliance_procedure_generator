# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.app_name}-vpc-${var.environment}"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Public Subnet (for load balancer and bastion)
resource "google_compute_subnetwork" "public" {
  name          = "${var.app_name}-public-subnet-${var.environment}"
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 8, 1)
  region        = var.region
  network       = google_compute_network.main.id
  project       = var.project_id

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Private Subnet (for Cloud Run and Cloud SQL)
resource "google_compute_subnetwork" "private" {
  name          = "${var.app_name}-private-subnet-${var.environment}"
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 8, 2)
  region        = var.region
  network       = google_compute_network.main.id
  project       = var.project_id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# VPC Access Connector for Cloud Run
resource "google_vpc_access_connector" "connector" {
  name          = "${var.app_name}-vpc-connector-${var.environment}"
  region        = var.region
  network       = google_compute_network.main.name
  ip_cidr_range = "10.8.0.0/28"  # Use a fixed CIDR instead of dynamic calculation
  project       = var.project_id

  # Minimize resource usage
  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3

  # Add timeouts
  timeouts {
    create = "45m"
    delete = "45m"
  }

  depends_on = [
    google_compute_network.main,
    google_compute_subnetwork.private,
    google_compute_router_nat.nat  # Add dependency on NAT gateway
  ]
}

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "${var.app_name}-router-${var.environment}"
  region  = var.region
  network = google_compute_network.main.id
  project = var.project_id
}

# Cloud NAT for private subnet internet access
resource "google_compute_router_nat" "nat" {
  name                               = "${var.app_name}-nat-${var.environment}"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  project                            = var.project_id

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Firewall rule - Allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.app_name}-allow-internal-${var.environment}"
  network = google_compute_network.main.name
  project = var.project_id

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

  source_ranges = [var.vpc_cidr]
  priority      = 1000
}

# Firewall rule - Allow SSH from IAP (Identity-Aware Proxy)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.app_name}-allow-iap-ssh-${var.environment}"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's IP range for SSH tunneling
  source_ranges = ["35.235.240.0/20"]
  priority      = 1000
}

# Firewall rule - Allow health checks
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.app_name}-allow-health-checks-${var.environment}"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "8082"]
  }

  # Google Cloud health check IP ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  priority      = 1000
}
