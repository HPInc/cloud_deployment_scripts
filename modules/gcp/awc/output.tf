/*
 * © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "public-ip" {
  value = module.awc-regional[*].public-ip
}

output "instance-self-link-list" {
  value = module.awc-regional[*].instance-self-link-list
}
