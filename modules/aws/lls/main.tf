/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix              = var.prefix != "" ? "${var.prefix}-" : ""
  host_name           = "${local.prefix}vm-lls"
  provisioning_script = "lls-provisioning.sh"
}

resource "aws_s3_bucket_object" "lls-provisioning-script" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  key     = local.provisioning_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      aws_region              = var.aws_region, 
      customer_master_key_id  = var.customer_master_key_id,
      lls_admin_password      = var.lls_admin_password,
      lls_activation_code     = var.lls_activation_code,
      lls_license_count       = var.lls_license_count,
      teradici_download_token = var.teradici_download_token,
    }
  )
}

data "template_file" "user-data" {
  template = file("${path.module}/user-data.sh.tmpl")

  vars = {
    bucket_name = var.bucket_name,
    file_name   = local.provisioning_script,
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

resource "aws_iam_role" "lls-role" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name               = "${local.prefix}lls_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_kms_key" "encryption-key" {
  count = var.customer_master_key_id == "" ? 0 : 1

  key_id = var.customer_master_key_id
}

data "aws_iam_policy_document" "lls-policy-doc" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.provisioning_script}"]
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

resource "aws_iam_role_policy" "lls-role-policy" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name = "${local.prefix}lls_role_policy"
  role = aws_iam_role.lls-role[0].id
  policy = data.aws_iam_policy_document.lls-policy-doc.json
}

resource "aws_iam_instance_profile" "lls-instance-profile" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name = "${local.prefix}lls_instance_profile"
  role = aws_iam_role.lls-role[0].name
}

resource "aws_instance" "lls" {
  count = var.instance_count

  ami           = data.aws_ami.ami.id
  instance_type = var.instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.disk_size_gb
  }

  subnet_id = var.subnet

  vpc_security_group_ids = var.security_group_ids

  key_name = var.admin_ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.lls-instance-profile[0].name

  user_data = data.template_file.user-data.rendered

  tags = {
    Name = "${local.host_name}-${count.index}"
  }
}
