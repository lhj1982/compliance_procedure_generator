resource "google_service_account" "bastion" {
  account_id   = "bastion-sa"
  display_name = "Bastion Service Account"
}

resource "google_compute_instance" "bastion" {
  name         = "bastion"
  machine_type = "e2-micro"
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = var.vpc_id
    subnetwork = var.private_subnet_id
  }

  # Allow IAP tunnel
  metadata = {
    enable-oslogin = "TRUE"
  }

  tags = ["bastion"]

  service_account {
    email  = google_service_account.bastion.email
    scopes = ["cloud-platform"]
  }
}

# Allow bastion to invoke the backend service
resource "google_cloud_run_v2_service_iam_member" "bastion_invoker" {
  location = var.region
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.bastion.email}"
}