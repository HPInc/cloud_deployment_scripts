/*
 * © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "awc-igm" {
  value = google_compute_region_instance_group_manager.awc-igm[*].self_link
}
