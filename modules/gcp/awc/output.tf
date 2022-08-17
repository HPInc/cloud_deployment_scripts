/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "public-ip" {
  value = module.cac-regional[*].public-ip
}

output "instance-self-link-list" {
  value = module.cac-regional[*].instance-self-link-list
}
