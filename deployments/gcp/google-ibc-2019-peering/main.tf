/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  num_ws_vpcs = length(var.workstation_vpc_names)
}

resource "google_compute_network" "vpc-cam" {
  name                    = "${local.prefix}${var.vpc_name}"
  auto_create_subnetworks = "false"
}

data "google_compute_network" "vpc_workstations" {
  count = local.num_ws_vpcs

  name = var.workstation_vpc_names[count.index]
}

resource "google_compute_network_peering" "peer_from_cam" {
  count = local.num_ws_vpcs

  name         = "cam-to-${var.workstation_vpc_names[count.index]}"
  network      = google_compute_network.vpc-cam.self_link
  peer_network = data.google_compute_network.vpc_workstations[count.index].self_link
}

resource "google_compute_network_peering" "peer_to_cam" {
  count = local.num_ws_vpcs

  name         = "${var.workstation_vpc_names[count.index]}-to-cam"
  network      = data.google_compute_network.vpc_workstations[count.index].self_link
  peer_network = google_compute_network.vpc-cam.self_link
}
