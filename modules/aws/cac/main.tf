/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  provisioning_script = "cac-provisioning.sh"
  cas_mgr_script      = "get-cac-token.py"

  instance_info_list = flatten(
    [ for i in range(length(var.zone_list)):
      [ for j in range(var.instance_count_list[i]):
        {
          zone   = var.zone_list[i],
          subnet = var.subnet_list[i],
        }
      ]
    ]
  )
  ssl_key_filename  = var.ssl_key  == "" ? "" : basename(var.ssl_key)
  ssl_cert_filename = var.ssl_cert == "" ? "" : basename(var.ssl_cert)

  aws_logs_script = "awslogs.sh"
}

resource "aws_s3_bucket_object" "get-cac-token-script" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  bucket = var.bucket_name
  key    = local.cas_mgr_script
  source = "${path.module}/${local.cas_mgr_script}"
}

resource "aws_s3_bucket_object" "ssl-key" {
  count = length(local.instance_info_list) == 0 ? 0 : var.ssl_key == "" ? 0 : 1

  bucket = var.bucket_name
  key    = local.ssl_key_filename
  source = var.ssl_key
}

resource "aws_s3_bucket_object" "ssl-cert" {
  count = length(local.instance_info_list) == 0 ? 0 : var.ssl_cert == "" ? 0 : 1

  bucket = var.bucket_name
  key    = local.ssl_cert_filename
  source = var.ssl_cert
}

resource "aws_s3_bucket_object" "cac-provisioning-script" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  key     = local.provisioning_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      ad_service_account_password = var.ad_service_account_password,
      ad_service_account_username = var.ad_service_account_username,
      aws_region                  = var.aws_region,
      bucket_name                 = var.bucket_name,
      cac_extra_install_flags     = var.cac_extra_install_flags,
      cac_version                 = var.cac_version,
      cas_mgr_deployment_sa_file  = var.cas_mgr_deployment_sa_file,
      cas_mgr_insecure            = var.cas_mgr_insecure ? "true" : "",
      cas_mgr_script              = local.cas_mgr_script,
      cas_mgr_url                 = var.cas_mgr_url,
      customer_master_key_id      = var.customer_master_key_id,
      domain_controller_ip        = var.domain_controller_ip,
      domain_name                 = var.domain_name,
      lls_ip                      = var.lls_ip,
      ssl_key                     = local.ssl_key_filename,
      ssl_cert                    = local.ssl_cert_filename,
      teradici_download_token     = var.teradici_download_token,
    }
  )
}

data "template_file" "user-data" {
  template = file("${path.module}/user-data.sh.tmpl")

  vars = {
    bucket_name         = var.bucket_name,
    provisioning_script = local.provisioning_script,
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
  count = length(local.instance_info_list) == 0 ? 0 : 1

  name               = "${local.prefix}cac_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_kms_key" "encryption-key" {
  count = var.customer_master_key_id == "" ? 0 : 1

  key_id = var.customer_master_key_id
}

data "aws_iam_policy_document" "cac-policy-doc" {
  statement {
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
    effect    = "Allow"
  }
  
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.provisioning_script}"]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.cas_mgr_script}"]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${var.cas_mgr_deployment_sa_file}"]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.aws_logs_script}"]
    effect    = "Allow"
  }

  statement {
    actions   = ["logs:CreateLogGroup",
                 "logs:CreateLogStream",
                 "logs:PutLogEvents",
                 "logs:DescribeLogStreams"]
    resources = ["arn:aws:logs:*:*:*"]
    effect    = "Allow"
  }

  dynamic statement {
    for_each = aws_s3_bucket_object.ssl-key
    iterator = i
    content {
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::${var.bucket_name}/${local.ssl_key_filename}"]
      effect    = "Allow"
    }
  }

  dynamic statement {
    for_each = aws_s3_bucket_object.ssl-cert
    iterator = i
    content {
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::${var.bucket_name}/${local.ssl_cert_filename}"]
      effect    = "Allow"
    }
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

resource "aws_iam_role_policy" "cac-role-policy" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  name = "${local.prefix}cac_role_policy"
  role = aws_iam_role.cac-role[0].id
  policy = data.aws_iam_policy_document.cac-policy-doc.json
}

resource "aws_iam_instance_profile" "cac-instance-profile" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  name = "${local.prefix}cac_instance_profile"
  role = aws_iam_role.cac-role[0].name
}

resource "aws_instance" "cac" {
  count = length(local.instance_info_list)

  depends_on = [
    aws_s3_bucket_object.ssl-key,
    aws_s3_bucket_object.ssl-cert,
    aws_s3_bucket_object.get-cac-token-script,
    aws_s3_bucket_object.cac-provisioning-script,
  ]

  availability_zone = local.instance_info_list[count.index].zone
  subnet_id         = local.instance_info_list[count.index].subnet

  ami           = data.aws_ami.ami.id
  instance_type = var.instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.disk_size_gb
  }

  associate_public_ip_address = true

  vpc_security_group_ids = var.security_group_ids

  key_name = var.admin_ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.cac-instance-profile[0].name

  user_data = data.template_file.user-data.rendered

  tags = {
    Name = "${local.prefix}${var.host_name}-${count.index}"
  }
}

resource "aws_cloudwatch_log_group" "instance-log-group" {
  count = length(local.instance_info_list)

  name = "${local.prefix}${var.host_name}-${count.index}"
}

