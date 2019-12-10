/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
}

module "dc" {
  source = "../../../modules/aws/dc"

  prefix = var.prefix
  
  domain_name              = var.domain_name
  admin_password           = var.dc_admin_password
  safe_mode_admin_password = var.safe_mode_admin_password
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password
  domain_users_list        = var.domain_users_list

  subnet = aws_subnet.dc-subnet.id
  private_ip = var.dc_private_ip
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-rdp.id,
    aws_security_group.allow-winrm.id,
    aws_security_group.allow-icmp.id,
  ]

  instance_type = var.dc_instance_type
  disk_size_gb  = var.dc_disk_size_gb

  ami_owner = var.dc_ami_owner
  ami_name  = var.dc_ami_name
}
