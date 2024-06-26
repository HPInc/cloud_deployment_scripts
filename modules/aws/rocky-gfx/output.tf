/*
 * © Copyright 2024 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "internal-ip" {
  value = aws_instance.rocky-gfx[*].private_ip
}

output "public-ip" {
  value = var.enable_public_ip ? aws_instance.rocky-gfx[*].public_ip : []
}
