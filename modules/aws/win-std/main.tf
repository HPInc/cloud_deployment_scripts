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

  enable_public_ip = var.enable_public_ip ? [true] : []
  startup_script = "win-std-startup.ps1"
}

resource "aws_s3_bucket_object" "win-std-startup-script" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  key     = local.startup_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.startup_script}.tmpl",
    {
      customer_master_key_id   = var.customer_master_key_id,
      pcoip_agent_location     = var.pcoip_agent_location,
      pcoip_agent_filename     = var.pcoip_agent_filename,
      pcoip_registration_code  = var.pcoip_registration_code,

      domain_name              = var.domain_name,
      admin_password           = var.admin_password,
      service_account_username = var.service_account_username,
      service_account_password = var.service_account_password,
    }
  )
}

data "template_file" "user-data" {
  template = file("${path.module}/user-data.ps1.tmpl")

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

resource "aws_iam_role" "win-std-role" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name               = "win_std_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_kms_key" "encryption-key" {
  count = var.customer_master_key_id == "" ? 0 : 1

  key_id = var.customer_master_key_id
}

data "aws_iam_policy_document" "win-std-policy-doc" {
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

resource "aws_iam_role_policy" "win-std-role-policy" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name = "win_std_role_policy"
  role = aws_iam_role.win-std-role[0].id
  policy = data.aws_iam_policy_document.win-std-policy-doc.json
}

resource "aws_iam_instance_profile" "win-std-instance-profile" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name = "win_std_instance_profile"
  role = aws_iam_role.win-std-role[0].name
}

resource "aws_instance" "win-std" {
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

  iam_instance_profile = aws_iam_instance_profile.win-std-instance-profile[0].name

  user_data = data.template_file.user-data.rendered

  tags = {
    Name = "${local.host_name}-${count.index}"
  }
}
