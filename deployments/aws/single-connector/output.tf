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

output "cac-internal-ip" {
  value = module.cac.internal-ip
}

output "cac-public-ip" {
  value = module.cac.public-ip
}

output "centos-std-internal-ip" {
  value = module.centos-std.internal-ip
}

output "centos-std-public-ip" {
  value = module.centos-std.public-ip
}
