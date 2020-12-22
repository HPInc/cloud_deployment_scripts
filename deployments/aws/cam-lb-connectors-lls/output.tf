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

output "lls-internal-ip" {
  value = module.lls.internal-ip
}

output "load-balancer-url" {
  value = aws_lb.cac-alb.dns_name
}

output "cam-public-ip" {
  value = module.cam.public-ip
}

output "cac-internal-ip" {
  value = module.cac.internal-ip
}

output "cac-public-ip" {
  value = module.cac.public-ip
}

output "win-gfx-internal-ip" {
  value = module.win-gfx.internal-ip
}

output "win-gfx-public-ip" {
  value = module.win-gfx.public-ip
}

output "win-std-internal-ip" {
  value = module.win-std.internal-ip
}

output "win-std-public-ip" {
  value = module.win-std.public-ip
}

output "centos-gfx-internal-ip" {
  value = module.centos-gfx.internal-ip
}

output "centos-gfx-public-ip" {
  value = module.centos-gfx.public-ip
}

output "centos-std-internal-ip" {
  value = module.centos-std.internal-ip
}

output "centos-std-public-ip" {
  value = module.centos-std.public-ip
}
