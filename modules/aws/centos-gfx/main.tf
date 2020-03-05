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

  startup_script = "centos-gfx-startup.sh"
}

resource "aws_s3_bucket_object" "centos-gfx-startup-script" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  key     = local.startup_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.startup_script}.tmpl",
    {
      aws_region                  = var.aws_region, 
      customer_master_key_id      = var.customer_master_key_id,
      pcoip_registration_code     = var.pcoip_registration_code,
      domain_controller_ip        = var.domain_controller_ip,
      domain_name                 = var.domain_name,
      ad_service_account_username = var.ad_service_account_username,
      ad_service_account_password = var.ad_service_account_password,
      nvidia_driver_url           = var.nvidia_driver_url,
      pcoip_agent_repo_pubkey_url = var.pcoip_agent_repo_pubkey_url,
      pcoip_agent_repo_url        = var.pcoip_agent_repo_url,
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
    name   = "product-code"
    values = [var.ami_product_code]
  }

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

data "aws_kms_key" "encryption-key" {
  count = var.customer_master_key_id == "" ? 0 : 1

  key_id = var.customer_master_key_id
}

resource "aws_iam_role" "centos-gfx-role" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name               = "centos_gfx_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_iam_policy_document" "centos-gfx-policy-doc" {
  statement {
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.startup_script}"]
    effect    = "Allow"
  }

  dynamic statement {
    for_each = data.aws_kms_key.encryption-key
    iterator = i
    content {
      actions   = ["kms:Decrypt"]
      resources = [i.value.arn]
      effect    = "Allow"
    }
  }
}

resource "aws_iam_role_policy" "centos-gfx-role-policy" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name = "centos_gfx_role_policy"
  role = aws_iam_role.centos-gfx-role[0].id
  policy = data.aws_iam_policy_document.centos-gfx-policy-doc.json
}

resource "aws_iam_instance_profile" "centos-gfx-instance-profile" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name = "centos_gfx_instance_profile"
  role = aws_iam_role.centos-gfx-role[0].name
}

resource "aws_instance" "centos-gfx" {
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

  iam_instance_profile = aws_iam_instance_profile.centos-gfx-instance-profile[0].name

  user_data = data.template_file.user-data.rendered

  tags = {
    Name = "${local.host_name}-${count.index}"
  }
}
