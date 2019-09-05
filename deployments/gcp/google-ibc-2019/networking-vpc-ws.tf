/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

data "google_compute_network" "vpc_workstations" {
  count = local.num_ws_vpcs

  name = var.workstation_vpc_names[count.index]
}

data "google_compute_subnetwork" "subnet_workstations" {
  count = local.num_ws_vpcs

  name   = var.workstation_subnet_names[count.index]
  region = var.workstation_subnet_regions[count.index]
}

resource "google_dns_managed_zone" "peering_zone" {
  provider    = "google-beta"
  count       = local.num_ws_vpcs

  name        = replace("${local.prefix}${var.workstation_vpc_names[count.index]}-peering-zone", ".", "-")
  dns_name    = "${var.domain_name}."
  description = "Peering zone for ${var.domain_name}"

  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = data.google_compute_network.vpc_workstations[count.index].self_link
    }
  }

  peering_config {
    target_network {
      network_url = data.google_compute_network.vpc-cam.self_link
    }
  }
}

resource "google_compute_firewall" "allow-internal-vpc-workstations" {
  count = local.num_ws_vpcs

  name    = "${local.prefix}fw-allow-internal-${var.workstation_vpc_names[count.index]}"
  network = data.google_compute_network.vpc_workstations[count.index].self_link

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

  source_ranges = [var.dc_subnet_cidr, var.cac_subnet_cidr, data.google_compute_subnetwork.subnet_workstations[count.index].ip_cidr_range]
}

resource "google_compute_firewall" "allow-ssh-vpc-workstations" {
  count = local.num_ws_vpcs

  name    = "${local.prefix}fw-allow-ssh-${var.workstation_vpc_names[count.index]}"
  network = data.google_compute_network.vpc_workstations[count.index].self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["${local.prefix}fw-allow-ssh-${var.workstation_vpc_names[count.index]}"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-rdp-vpc-workstations" {
  count = local.num_ws_vpcs

  name    = "${local.prefix}fw-allow-rdp-${var.workstation_vpc_names[count.index]}"
  network = data.google_compute_network.vpc_workstations[count.index].self_link

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  allow {
    protocol = "udp"
    ports    = ["3389"]
  }

  target_tags   = ["${local.prefix}fw-allow-rdp-${var.workstation_vpc_names[count.index]}"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-icmp-vpc-workstations" {
  count = local.num_ws_vpcs

  name    = "${local.prefix}fw-allow-icmp-${var.workstation_vpc_names[count.index]}"
  network = data.google_compute_network.vpc_workstations[count.index].self_link

  allow {
    protocol = "icmp"
  }

  target_tags   = ["${local.prefix}fw-allow-icmp-${var.workstation_vpc_names[count.index]}"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}
