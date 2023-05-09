/*
 * © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "public-ip" {
  value = (var.enable_awc_external_ip || var.external_pcoip_ip == "") ? google_compute_instance.awc[*].network_interface[0].access_config[0].nat_ip : []
}

output "instance-self-link-list" {
  value = google_compute_instance.awc[*].self_link
}
