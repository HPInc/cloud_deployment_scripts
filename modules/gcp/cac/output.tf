/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "internal-ip" {
  value = [google_compute_instance.cac[*].network_interface[0].network_ip]
}

output "public-ip" {
  value = [google_compute_instance.cac[*].network_interface[0].access_config[0].nat_ip]
}

output "instance-self-links" {
  value = [google_compute_instance.cac[*].self_link]
}
