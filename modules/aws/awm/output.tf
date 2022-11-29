/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "internal-ip" {
  value = aws_instance.awm.private_ip
}

output "public-ip" {
  value = aws_instance.awm.public_ip
}

output "instance-id" {
  value = aws_instance.awm.id
}
