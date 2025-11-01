# Bastion Host for secure access to private resources
# Using a small, cost-optimized instance

# Service account for bastion
resource "google_service_account" "bastion" {
  account_id   = "${var.app_name}-bastion-${var.environment}"
  display_name = "Bastion Host Service Account"
  project      = var.project_id
}

# Bastion host instance
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
    # If you need external IP, uncomment below
    # access_config {}
  }

  service_account {
    email  = google_service_account.bastion.email
    scopes = ["cloud-platform"]
  }

  # Allow stopping for maintenance
  allow_stopping_for_update = true

  # Enable OS Login for better security
  metadata = {
    enable-oslogin = "TRUE"
  }

  # Startup script to install necessary tools
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y postgresql-client curl wget

    # Install gcloud SQL proxy
    wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /usr/local/bin/cloud_sql_proxy
    chmod +x /usr/local/bin/cloud_sql_proxy
  EOF

  scheduling {
    # Use preemptible for dev to save costs (will be terminated within 24h)
    preemptible         = var.environment != "prod"
    automatic_restart   = var.environment == "prod"
    # on_host_maintenance = "MIGRATE"
  }
}

# Firewall rule for bastion SSH access via IAP
resource "google_compute_firewall" "bastion_ssh" {
  name    = "${var.app_name}-bastion-ssh-${var.environment}"
  network = var.vpc_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["bastion"]
}

# Optional: Firewall rule for bastion to access from specific IPs
# Uncomment if you want direct SSH access (not recommended, use IAP instead)
# resource "google_compute_firewall" "bastion_external_ssh" {
#   name    = "${var.app_name}-bastion-external-ssh-${var.environment}"
#   network = var.vpc_name
#   project = var.project_id
#
#   allow {
#     protocol = "tcp"
#     ports    = ["22"]
#   }
#
#   source_ranges = var.bastion_allowed_ips
#   target_tags   = ["bastion"]
# }

# IAM role for Cloud SQL Client access from bastion
resource "google_project_iam_member" "bastion_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.bastion.email}"
}
