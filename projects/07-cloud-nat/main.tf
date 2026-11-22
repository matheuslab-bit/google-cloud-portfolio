# Read Lab 01 and Lab 02 resources through the API, without touching their state.
data "google_compute_network" "existing" {
  project = var.project_id
  name    = var.network_name
}

data "google_compute_subnetwork" "lab02" {
  project = var.project_id
  name    = var.subnet_name
  region  = var.region
}

# Cloud NAT runs on a Cloud Router. The router here has no BGP peers; it only hosts the NAT config.
resource "google_compute_router" "nat" {
  project = var.project_id
  name    = "lab07-nat-router"
  region  = var.region
  network = data.google_compute_network.existing.self_link
}

# Outbound-only internet access for the private VM: nothing on the internet can open a connection back in.
resource "google_compute_router_nat" "nat" {
  project = var.project_id
  name    = "lab07-nat"
  router  = google_compute_router.nat.name
  region  = var.region

  # Google picks and manages the external IP. No reserved address is left behind after destroy.
  nat_ip_allocate_option = "AUTO_ONLY"

  # Only the Lab 02 subnet gets NAT, not every subnet in the region.
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = data.google_compute_subnetwork.lab02.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  # Log only translation errors (for example, ports running out): enough to troubleshoot, tiny log volume.
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
