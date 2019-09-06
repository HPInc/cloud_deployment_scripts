/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "cac-igm" {
  value = google_compute_instance_group_manager.cac-igm[*].self_link
}
