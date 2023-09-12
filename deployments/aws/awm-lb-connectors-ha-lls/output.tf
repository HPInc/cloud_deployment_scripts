/*
 * Copyright Teradici Corporation 2020-2021;  © Copyright 2022-2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "domain-controller-internal-ip" {
  value = module.dc.internal-ip
}

output "awm-public-ip" {
  value = module.awm.public-ip
}

output "load-balancer-url" {
  value = aws_lb.awc-alb.dns_name
}

output "awc-internal-ip" {
  value = module.awc.internal-ip
}

output "awc-public-ip" {
  value = module.awc.public-ip
}

output "haproxy-master-ip" {
  value = module.ha-lls.haproxy-master-ip
}

output "haproxy-backup-ip" {
  value = module.ha-lls.haproxy-backup-ip
}

output "lls-main-ip" {
  value = module.ha-lls.lls-main-ip
}

output "lls-backup-ip" {
  value = module.ha-lls.lls-backup-ip
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
