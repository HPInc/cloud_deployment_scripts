/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "peering_from_cam" {
  value = google_compute_network_peering.peer_from_cam[*].state
}

output "peering_to_cam" {
  value = google_compute_network_peering.peer_to_cam[*].state
}
