# ============================================================================
# Bastion Host - Secure access to private resources
# ============================================================================

# Bastion compute instance
resource "google_compute_instance" "bastion" {
  name         = "${var.app_name}-bastion-${var.environment}"
  machine_type = "e2-micro" # Cheapest machine type
  zone         = "${var.region}-a"
  project      = var.project_id

  tags = ["bastion", "ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10 # GB - minimum size
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = var.public_subnet_name
    # No external IP - use IAP for SSH access (more secure and free)
  }

  service_account {
    email  = google_service_account.bastion.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true

  # Enable OS Login for better security
  metadata = {
    enable-oslogin = "TRUE"
  }

  # Install necessary tools on startup
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y postgresql-client curl wget

    # Install Cloud SQL proxy
    wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /usr/local/bin/cloud_sql_proxy
    chmod +x /usr/local/bin/cloud_sql_proxy
  EOF

  scheduling {
    # Use preemptible for dev to save costs (will be terminated within 24h)
    preemptible       = var.environment != "prod"
    automatic_restart = var.environment == "prod"
  }
}

# ============================================================================
# Bastion Firewall Rules
# ============================================================================

# Allow SSH access via IAP
resource "google_compute_firewall" "bastion_iap_ssh" {
  name    = "${var.app_name}-bastion-iap-ssh-${var.environment}"
  network = var.vpc_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's IP range for SSH tunneling
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["bastion"]
}

# ============================================================================
# Bastion IAM
# ============================================================================

# Allow bastion to connect to Cloud SQL
resource "google_project_iam_member" "bastion_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.bastion.email}"
}
