/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

resource "google_compute_network" "vpc-cam" {
  name                    = "${local.prefix}${var.vpc_name}"
  auto_create_subnetworks = "false"
}

resource "google_dns_managed_zone" "private_zone" {
  provider    = "google-beta"

  name        = replace("${local.prefix}${var.domain_name}-zone", ".", "-")
  dns_name    = "${var.domain_name}."
  description = "Private forwarding zone for ${var.domain_name}"

  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc-cam.self_link
    }
  }

  forwarding_config {
    target_name_servers {
      ipv4_address = var.dc_private_ip
    }
  }
}

resource "google_compute_firewall" "allow-internal-vpc-cam" {
  name    = "${local.prefix}fw-allow-internal-vpc-cam"
  network = google_compute_network.vpc-cam.self_link

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

  source_ranges = flatten([var.dc_subnet_cidr, var.cac_subnet_cidr, data.google_compute_subnetwork.subnet_workstations[*].ip_cidr_range])
}

resource "google_compute_firewall" "allow-ssh-vpc-cam" {
  name    = "${local.prefix}fw-allow-ssh-vpc-cam"
  network = google_compute_network.vpc-cam.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["${local.prefix}fw-allow-ssh-vpc-cam"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-http-vpc-cam" {
  name    = "${local.prefix}fw-allow-http-vpc-cam"
  network = google_compute_network.vpc-cam.self_link

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags   = ["${local.prefix}fw-allow-http-vpc-cam"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-https-vpc-cam" {
  name    = "${local.prefix}fw-allow-https-vpc-cam"
  network = google_compute_network.vpc-cam.self_link

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  target_tags   = ["${local.prefix}fw-allow-https-vpc-cam"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-rdp-vpc-cam" {
  name    = "${local.prefix}fw-allow-rdp-vpc-cam"
  network = google_compute_network.vpc-cam.self_link

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  allow {
    protocol = "udp"
    ports    = ["3389"]
  }

  target_tags   = ["${local.prefix}fw-allow-rdp-vpc-cam"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-winrm-vpc-cam" {
  name    = "${local.prefix}fw-allow-winrm-vpc-cam"
  network = google_compute_network.vpc-cam.self_link

  allow {
    protocol = "tcp"
    ports    = ["5985-5986"]
  }

  target_tags   = ["${local.prefix}fw-allow-winrm-vpc-cam"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-icmp-vpc-cam" {
  name    = "${local.prefix}fw-allow-icmp-vpc-cam"
  network = google_compute_network.vpc-cam.self_link

  allow {
    protocol = "icmp"
  }

  target_tags   = ["${local.prefix}fw-allow-icmp-vpc-cam"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-pcoip-vpc-cam" {
  name    = "${local.prefix}fw-allow-pcoip-vpc-cam"
  network = google_compute_network.vpc-cam.self_link

  allow {
    protocol = "tcp"
    ports    = ["4172"]
  }
  allow {
    protocol = "udp"
    ports    = ["4172"]
  }

  target_tags   = ["${local.prefix}fw-allow-pcoip-vpc-cam"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-dns-vpc-cam" {
  name    = "${local.prefix}fw-allow-dns-vpc-cam"
  network = google_compute_network.vpc-cam.self_link

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }
  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  target_tags   = ["${local.prefix}fw-allow-dns-vpc-cam"]
  source_ranges = ["35.199.192.0/19"]
}

resource "google_compute_subnetwork" "dc-subnet" {
  name          = "${local.prefix}subnet-dc"
  ip_cidr_range = var.dc_subnet_cidr
  network       = google_compute_network.vpc-cam.self_link
}

resource "google_compute_subnetwork" "cac-subnet" {
  name          = "${local.prefix}subnet-cac"
  ip_cidr_range = var.cac_subnet_cidr
  network       = google_compute_network.vpc-cam.self_link
}

resource "google_compute_address" "dc-internal-ip" {
  name         = "${local.prefix}static-ip-internal-dc"
  subnetwork   = google_compute_subnetwork.dc-subnet.self_link
  address_type = "INTERNAL"
  address      = var.dc_private_ip
}
