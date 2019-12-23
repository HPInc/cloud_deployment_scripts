/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  # Windows computer names must be <= 15 characters, minus 4 chars for "-xyz"
  # where xyz is number of instances (0-999)
  host_name = substr("${local.prefix}${var.name}", 0, 11)

  startup_script = "centos-std-startup.sh"
}

data "template_file" "startup-script" {
  template = file("${path.module}/${local.startup_script}.tmpl")

  vars = {
    pcoip_registration_code  = var.pcoip_registration_code,
    domain_controller_ip     = var.domain_controller_ip,
    domain_name              = var.domain_name,
    service_account_username = var.service_account_username,
    service_account_password = var.service_account_password,
  }
}

# Need to do this to look up AMI ID, which is different for each region
data "aws_ami" "ami" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

resource "aws_instance" "centos-std" {
  count = var.instance_count

  ami           = data.aws_ami.ami.id
  instance_type = var.instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.disk_size_gb
  }

  subnet_id                   = var.subnet
  associate_public_ip_address = var.enable_public_ip

  vpc_security_group_ids = var.security_group_ids

  key_name = var.admin_ssh_key_name

  user_data = data.template_file.startup-script.rendered

  tags = {
    Name = "${local.host_name}-${count.index}"
  }
}
