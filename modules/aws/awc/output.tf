/*
 * © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "internal-ip" {
  value = aws_instance.awc[*].private_ip
}

output "public-ip" {
  value = aws_instance.awc[*].public_ip
}

output "instance-id" {
  value = aws_instance.awc[*].id
}
