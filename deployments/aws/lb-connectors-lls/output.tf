/*
 * Copyright Teradici Corporation 2020;  © Copyright 2022-2024 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "domain-controller-internal-ip" {
  value = module.dc.internal-ip
}

output "lls-internal-ip" {
  value = module.lls.internal-ip
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

output "rocky-gfx-internal-ip" {
  value = module.rocky-gfx.internal-ip
}

output "rocky-gfx-public-ip" {
  value = module.rocky-gfx.public-ip
}

output "rocky-std-internal-ip" {
  value = module.rocky-std.internal-ip
}

output "rocky-std-public-ip" {
  value = module.rocky-std.public-ip
}
