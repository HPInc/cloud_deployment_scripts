/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  lls_host_name           = "${local.prefix}vm-lls"
  lls_provisioning_script = "lls-provisioning.sh"
}

resource "aws_s3_bucket_object" "lls-provisioning-script" {
  key     = local.lls_provisioning_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.lls_provisioning_script}.tmpl",
    {
      aws_region              = var.aws_region, 
      customer_master_key_id  = var.customer_master_key_id,
      lls_admin_password      = var.lls_admin_password,
      lls_activation_code     = var.lls_activation_code,
      lls_license_count       = var.lls_license_count,
      lls_main_ip             = var.assigned_ips["lls_main"],
      lls_backup_ip           = var.assigned_ips["lls_backup"],
      haproxy_master_ip       = var.assigned_ips["haproxy_master"],
      haproxy_backup_ip       = var.assigned_ips["haproxy_backup"],
      teradici_download_token = var.teradici_download_token,
    }
  )
}

data "template_file" "lls-user-data" {
  template = file("${path.module}/user-data.sh.tmpl")

  vars = {
    bucket_name = var.bucket_name,
    file_name   = local.lls_provisioning_script,
  }
}

# Need to do this to look up AMI ID, which is different for each region
data "aws_ami" "lls_ami" {
  most_recent = true
  owners      = [var.lls_ami_owner]

#  filter {
#    name   = "product-code"
#    values = [var.lls_ami_product_code]
#  }

  filter {
    name   = "name"
    values = [var.lls_ami_name]
  }
}

resource "aws_iam_role" "lls-role" {
  name               = "${local.prefix}lls_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_iam_policy_document" "lls-policy-doc" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.lls_provisioning_script}"]
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
  name = "${local.prefix}lls_role_policy"
  role = aws_iam_role.lls-role.id
  policy = data.aws_iam_policy_document.lls-policy-doc.json
}

resource "aws_iam_instance_profile" "lls-instance-profile" {
  name = "${local.prefix}lls_instance_profile"
  role = aws_iam_role.lls-role.name
}

resource "aws_instance" "lls_main" {
  ami           = data.aws_ami.lls_ami.id
  instance_type = var.lls_instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.lls_disk_size_gb
  }

  subnet_id  = var.subnet
  private_ip = var.assigned_ips["lls_main"]

  vpc_security_group_ids = var.security_group_ids

  key_name = var.admin_ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.lls-instance-profile.name

  user_data = data.template_file.lls-user-data.rendered

  tags = {
    Name = "${local.lls_host_name}-main"
  }
}

resource "aws_instance" "lls_backup" {
  ami           = data.aws_ami.lls_ami.id
  instance_type = var.lls_instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.lls_disk_size_gb
  }

  subnet_id  = var.subnet
  private_ip = var.assigned_ips["lls_backup"]

  vpc_security_group_ids = var.security_group_ids

  key_name = var.admin_ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.lls-instance-profile.name

  user_data = data.template_file.lls-user-data.rendered

  tags = {
    Name = "${local.lls_host_name}-backup"
  }
}
