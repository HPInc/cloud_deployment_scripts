/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "haproxy-master-ip" {
  value = aws_instance.haproxy_master.private_ip
}

output "haproxy-backup-ip" {
  value = aws_instance.haproxy_backup.private_ip
}

output "lls-main-ip" {
  value = aws_instance.lls_main.private_ip
}

output "lls-backup-ip" {
  value = aws_instance.lls_backup.private_ip
}
