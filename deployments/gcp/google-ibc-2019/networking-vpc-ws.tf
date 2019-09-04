/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

data "google_compute_network" "vpc-ws" {
  name = var.workstation_vpc_name
}

data "google_compute_subnetwork" "subnet-ws" {
  name   = var.workstation_subnet_name
  region = var.workstation_subnet_region
}

resource "google_dns_managed_zone" "peering_zone" {
  provider    = "google-beta"

  name        = replace("${local.prefix}${var.domain_name}-peering-zone", ".", "-")
  dns_name    = "${var.domain_name}."
  description = "Peering zone for ${var.domain_name}"

  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = data.google_compute_network.vpc-ws.self_link
    }
  }

  peering_config {
    target_network {
      network_url = google_compute_network.vpc-cam.self_link
    }
  }
}

resource "google_compute_firewall" "allow-internal-vpc-ws" {
  name    = "${local.prefix}fw-allow-internal-vpc-ws"
  network = data.google_compute_network.vpc-ws.self_link

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

  source_ranges = [var.dc_subnet_cidr, var.cac_subnet_cidr, data.google_compute_subnetwork.subnet-ws.ip_cidr_range]
}

resource "google_compute_firewall" "allow-ssh-vpc-ws" {
  name    = "${local.prefix}fw-allow-ssh-vpc-ws"
  network = data.google_compute_network.vpc-ws.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["${local.prefix}fw-allow-ssh-vpc-ws"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-rdp-vpc-ws" {
  name    = "${local.prefix}fw-allow-rdp-vpc-ws"
  network = data.google_compute_network.vpc-ws.self_link

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  allow {
    protocol = "udp"
    ports    = ["3389"]
  }

  target_tags   = ["${local.prefix}fw-allow-rdp-vpc-ws"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-icmp-vpc-ws" {
  name    = "${local.prefix}fw-allow-icmp-vpc-ws"
  network = data.google_compute_network.vpc-ws.self_link

  allow {
    protocol = "icmp"
  }

  target_tags   = ["${local.prefix}fw-allow-icmp-vpc-ws"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}
