# VPC Network
resource "google_compute_network" "redteam" {
  name                    = "${var.environment}-redteam-vpc"
  auto_create_subnetworks = "false"
}

locals {
  public_subnets = {
    for idx in range(length(var.subnet_regions)) : tostring(idx) => {
      region = var.subnet_regions[idx]
      cidr   = var.subnet_cidrs[idx]
    }
  }
}

# Subnets (for_each preferred over count for stable addressing)
resource "google_compute_subnetwork" "public" {
  for_each = local.public_subnets

  name          = "${var.environment}-public-subnet-${each.key}"
  ip_cidr_range = each.value.cidr
  region        = each.value.region
  network       = google_compute_network.redteam.id
}

# Firewall Rules
resource "google_compute_firewall" "redteam" {
  name    = "${var.environment}-redteam-fw"
  network = google_compute_network.redteam.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "7443", "3333", "8080"]
  }

  source_ranges = ["${var.admin_ip}", "0.0.0.0/0"]
  target_tags   = ["redteam"]
  # Note: google_compute_firewall does not support `labels` in hashicorp/google ~> 4.x;
  # use name prefix and target_tags for identification.
}

# Allow all internal traffic between VMs in the VPC
resource "google_compute_firewall" "internal" {
  name    = "${var.environment}-internal-fw"
  network = google_compute_network.redteam.name

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

  source_tags = ["redteam"]
  target_tags = ["redteam"]
}

# Cloud Router + NAT so private VMs (no public IP) can reach the internet
resource "google_compute_router" "nat_router" {
  name    = "${var.environment}-nat-router"
  region  = var.gcp_region
  network = google_compute_network.redteam.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.environment}-cloud-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = false
    filter = "ALL"
  }
}

# Only Redirector gets static reserved IP
resource "google_compute_address" "redirector_ip" {
  name = "${var.environment}-redirector-ip"
}

resource "google_compute_instance" "service" {
  for_each = var.machine_types

  name         = "${var.environment}-${each.key}-vm"
  machine_type = each.value
  zone         = "${var.gcp_region}-a"

  tags = ["redteam"]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
      type  = "pd-standard" # Standard HDD instead of pd-balanced/pd-ssd
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public["0"].id
    # Access config (Public IP) ONLY for redirector
    dynamic "access_config" {
      for_each = each.key == "redirector" ? [1] : []
      content {
        nat_ip = google_compute_address.redirector_ip.address
      }
    }
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.ssh_public_key_path)}"
    user-data = templatefile("${path.module}/templates/cloud-init-base.sh", {
      hostname = "${each.key}-${var.environment}"
    })
  }

  labels = {
    environment = var.environment
    service     = each.key
    provider    = "gcp"
  }
}
