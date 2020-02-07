/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix         = var.prefix != "" ? "${var.prefix}-" : ""
  startup_script = "cac-startup.sh"
}

resource "aws_s3_bucket_object" "cac-startup-script" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  key     = local.startup_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.startup_script}.tmpl",
    {
      cam_url                  = var.cam_url,
      cac_installer_url        = var.cac_installer_url,
      cac_token                = var.cac_token,
      pcoip_registration_code  = var.pcoip_registration_code,

      domain_controller_ip     = var.domain_controller_ip,
      domain_name              = var.domain_name,
      domain_group             = var.domain_group,
      service_account_username = var.service_account_username,
      service_account_password = var.service_account_password,
    }
  )
}

data "template_file" "user-data" {
  template = file("${path.module}/user-data.sh.tmpl")

  vars = {
    bucket_name = var.bucket_name,
    file_name   = local.startup_script,
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

data "aws_iam_policy_document" "instance-assume-role-policy-doc" {
  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cac-role" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name               = "cac_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_iam_policy_document" "cac-policy-doc" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.startup_script}"]
    effect    = "Allow"
  }
}

resource "aws_iam_role_policy" "cac-role-policy" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name = "cac_role_policy"
  role = aws_iam_role.cac-role[0].id
  policy = data.aws_iam_policy_document.cac-policy-doc.json
}

resource "aws_iam_instance_profile" "cac-instance-profile" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name = "cac_instance_profile"
  role = aws_iam_role.cac-role[0].name
}

resource "aws_instance" "cac" {
  count = var.instance_count

  ami           = data.aws_ami.ami.id
  instance_type = var.instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.disk_size_gb
  }

  subnet_id                   = var.subnet
  associate_public_ip_address = true

  vpc_security_group_ids = var.security_group_ids

  key_name = var.admin_ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.cac-instance-profile[0].name

  user_data = data.template_file.user-data.rendered

  tags = {
    Name = "${local.prefix}${var.host_name}-${count.index}"
  }
}
