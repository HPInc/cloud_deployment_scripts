/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

resource "google_compute_network" "vpc" {
  name                    = "${local.prefix}${var.vpc_name}"
  auto_create_subnetworks = "false"
}

resource "google_dns_managed_zone" "private_zone" {
  provider    = google-beta

  name        = replace("${local.prefix}${var.domain_name}-zone", ".", "-")
  dns_name    = "${var.domain_name}."
  description = "Private forwarding zone for ${var.domain_name}"

  visibility  = "private"

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

  source_ranges = concat([var.dc_subnet_cidr, var.ws_subnet_cidr], var.cac_subnet_cidr_list)
}

resource "google_compute_firewall" "allow-ssh" {
  name    = "${local.prefix}fw-allow-ssh"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["${local.prefix}fw-allow-ssh"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_admin_cidrs)
}

# Open TCP/443 for Google Load balancers to perform health checks
# https://cloud.google.com/load-balancing/docs/health-checks
resource "google_compute_firewall" "allow-google-health-check" {
  name    = "${local.prefix}fw-allow-google-health-check"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  target_tags   = ["${local.prefix}fw-allow-google-health-check"]
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

resource "google_compute_firewall" "allow-rdp" {
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
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_admin_cidrs)
}

resource "google_compute_firewall" "allow-winrm" {
  name    = "${local.prefix}fw-allow-winrm"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["5986"]
  }

  target_tags   = ["${local.prefix}fw-allow-winrm"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_admin_cidrs)
}

resource "google_compute_firewall" "allow-icmp" {
  name    = "${local.prefix}fw-allow-icmp"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "icmp"
  }

  target_tags   = ["${local.prefix}fw-allow-icmp"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_admin_cidrs)
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
  source_ranges = ["35.199.192.0/19"]
}

resource "google_compute_subnetwork" "dc-subnet" {
  name          = "${local.prefix}subnet-dc"
  ip_cidr_range = var.dc_subnet_cidr
  network       = google_compute_network.vpc.self_link
}

resource "google_compute_subnetwork" "cac-subnets" {
  count = length(var.cac_region_list)

  name          = "${local.prefix}subnet-cac-${var.cac_region_list[count.index]}"
  region        = var.cac_region_list[count.index]
  ip_cidr_range = var.cac_subnet_cidr_list[count.index]
  network       = google_compute_network.vpc.self_link
}

resource "google_compute_subnetwork" "ws-subnet" {
  name          = "${local.prefix}subnet-ws"
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
