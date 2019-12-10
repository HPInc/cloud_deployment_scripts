/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "domain-controller-internal-ip" {
  value = module.dc.internal-ip
}

output "domain-controller-public-ip" {
  value = module.dc.public-ip
}
