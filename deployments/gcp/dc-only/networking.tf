/*
 * Copyright Teradici Corporation 2021;  © Copyright 2021 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

data "http" "myip" {
  url = "https://api.ipify.org"
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

  source_ranges = [var.dc_subnet_cidr]
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

resource "google_compute_firewall" "allow-dns" {
  name    = "${local.prefix}fw-allow-dns"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }
  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  target_tags   = ["${local.prefix}fw-allow-dns"]
  source_ranges = ["35.199.192.0/19"]
}

resource "google_compute_subnetwork" "dc-subnet" {
  name          = "${local.prefix}${var.dc_subnet_name}"
  ip_cidr_range = var.dc_subnet_cidr
  network       = google_compute_network.vpc.self_link
}

resource "google_compute_address" "dc-internal-ip" {
  name         = "${local.prefix}static-ip-internal-dc"
  subnetwork   = google_compute_subnetwork.dc-subnet.self_link
  address_type = "INTERNAL"
  address      = var.dc_private_ip
}
