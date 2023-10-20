/*
 * Copyright Teradici Corporation 2019-2022;  © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  cloud_dns_cidr = ["35.199.192.0/19"]

  #Allows ingress traffic from the IP range 35.235.240.0/20. This range contains all IP addresses that IAP uses for TCP forwarding.
  iap_cidr = ["35.235.240.0/20"]
  myip     = module.myip.cidr
}
module "myip" {
  source = "../../../modules/shared/myip"
}

resource "google_compute_network" "vpc" {
  name                    = "${local.prefix}${var.vpc_name}"
  auto_create_subnetworks = "false"
}

resource "google_dns_managed_zone" "private_zone" {
  provider = google-beta

  name        = replace("${local.prefix}${var.domain_name}-zone", ".", "-")
  dns_name    = "${var.domain_name}."
  description = "Private forwarding zone for ${var.domain_name}"

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.self_link
    }
  }

  forwarding_config {
    target_name_servers {
      ipv4_address = var.dc_private_ip
    }
  }
}

resource "google_compute_firewall" "allow-internal" {
  name    = "${local.prefix}fw-allow-internal"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["1-65535"]
  }

  source_ranges = [var.dc_subnet_cidr, var.awc_subnet_cidr, var.ws_subnet_cidr]
}

resource "google_compute_firewall" "allow-ssh" {
  count  = var.enable_ssh ? 1 : 0

  name    = "${local.prefix}fw-allow-ssh"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["${local.prefix}fw-allow-ssh"]
  source_ranges = concat([local.myip], var.allowed_admin_cidrs)
}

# To allow IAP to connect to GCP VM instances
resource "google_compute_firewall" "allow-iap" {
  count  = var.gcp_iap_enable ? 1 : 0
  
  name    = "${local.prefix}fw-allow-iap"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  target_tags   = ["${local.prefix}fw-allow-iap"]
  source_ranges = local.iap_cidr
}

resource "google_compute_firewall" "allow-rdp" {
  count  = var.enable_rdp ? 1 : 0
  name    = "${local.prefix}fw-allow-rdp"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  allow {
    protocol = "udp"
    ports    = ["3389"]
  }

  target_tags   = ["${local.prefix}fw-allow-rdp"]
  source_ranges = concat([local.myip], var.allowed_admin_cidrs)
}

resource "google_compute_firewall" "allow-winrm" {
  name    = "${local.prefix}fw-allow-winrm"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["5986"]
  }

  target_tags   = ["${local.prefix}fw-allow-winrm"]
  source_ranges = concat([local.myip], var.allowed_admin_cidrs)
}

resource "google_compute_firewall" "allow-icmp" {
  count  = var.enable_icmp ? 1 : 0
  name    = "${local.prefix}fw-allow-icmp"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "icmp"
  }

  target_tags   = ["${local.prefix}fw-allow-icmp"]
  source_ranges = concat([local.myip], var.allowed_admin_cidrs)
}

resource "google_compute_firewall" "allow-pcoip" {
  name    = "${local.prefix}fw-allow-pcoip"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  allow {
    protocol = "tcp"
    ports    = ["4172"]
  }
  allow {
    protocol = "udp"
    ports    = ["4172"]
  }

  target_tags   = ["${local.prefix}fw-allow-pcoip"]
  source_ranges = var.allowed_client_cidrs
}

# Open TCP/UDP/53 for Google Cloud DNS managed zone
# https://cloud.google.com/dns/zones
resource "google_compute_firewall" "allow-google-dns" {
  name    = "${local.prefix}fw-allow-google-dns"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }
  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  target_tags   = ["${local.prefix}fw-allow-google-dns"]
  source_ranges = local.cloud_dns_cidr
}

resource "google_compute_subnetwork" "dc-subnet" {
  name          = "${local.prefix}${var.dc_subnet_name}"
  ip_cidr_range = var.dc_subnet_cidr
  network       = google_compute_network.vpc.self_link
}

resource "google_compute_subnetwork" "awc-subnet" {
  name          = "${local.prefix}${var.awc_subnet_name}"
  ip_cidr_range = var.awc_subnet_cidr
  network       = google_compute_network.vpc.self_link
}

resource "google_compute_subnetwork" "ws-subnet" {
  name          = "${local.prefix}${var.ws_subnet_name}"
  ip_cidr_range = var.ws_subnet_cidr
  network       = google_compute_network.vpc.self_link
}

resource "google_compute_address" "dc-internal-ip" {
  name         = "${local.prefix}static-ip-internal-dc"
  subnetwork   = google_compute_subnetwork.dc-subnet.self_link
  address_type = "INTERNAL"
  address      = var.dc_private_ip
}

resource "google_compute_router" "router" {
  name    = "${local.prefix}router"
  region  = var.gcp_region
  network = google_compute_network.vpc.self_link

  bgp {
    asn = 65000
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "${local.prefix}nat"
  router                             = google_compute_router.router.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  min_ports_per_vm                   = 2048

  subnetwork {
    name                    = google_compute_subnetwork.ws-subnet.self_link
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"]
  }
}
