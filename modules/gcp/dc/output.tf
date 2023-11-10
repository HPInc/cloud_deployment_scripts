/*
 * Copyright Teradici Corporation 2019;  © Copyright 2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "internal-ip" {
  value = google_compute_instance.dc.network_interface[0].network_ip
}

