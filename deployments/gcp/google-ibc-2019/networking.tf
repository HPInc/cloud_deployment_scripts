/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

resource "google_compute_network_peering" "peer1" {
  name         = "peer1"
  network      = google_compute_network.vpc-cam.self_link
  peer_network = data.google_compute_network.vpc-ws.self_link
}

resource "google_compute_network_peering" "peer2" {
  name         = "peer2"
  network      = data.google_compute_network.vpc-ws.self_link
  peer_network = google_compute_network.vpc-cam.self_link
}
