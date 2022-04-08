/*
 * Copyright Teradici Corporation 2020-2021;  © Copyright 2022 HP Development Company, L.P.
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

output "cas-mgr-public-ip" {
  value = module.cas-mgr.public-ip
}

output "load-balancer-url" {
  value = aws_lb.cas-connector-alb.dns_name
}

output "cas-connector-internal-ip" {
  value = module.cas-connector.internal-ip
}

output "cas-connector-public-ip" {
  value = module.cas-connector.public-ip
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
