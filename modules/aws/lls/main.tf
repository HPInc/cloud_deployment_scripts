/*
 * Copyright Teradici Corporation 2020-2022;  © Copyright 2022-2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix              = var.prefix != "" ? "${var.prefix}-" : ""
  host_name           = "${local.prefix}vm-lls"
  provisioning_script = "lls-provisioning.sh"
}

resource "aws_s3_object" "lls-provisioning-script" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  key    = local.provisioning_script
  bucket = var.bucket_name
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      aws_region              = var.aws_region,
      aws_ssm_enable          = var.aws_ssm_enable,
      bucket_name             = var.bucket_name,
      cloudwatch_enable       = var.cloudwatch_enable,
      cloudwatch_setup_script = var.cloudwatch_setup_script,
      lls_activation_code_id  = var.lls_activation_code_id,
      lls_admin_password_id   = var.lls_admin_password_id,
      lls_license_count       = var.lls_license_count,
      teradici_download_token = var.teradici_download_token,
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
    actions = ["sts:AssumeRole"]

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

data "aws_iam_policy_document" "lls-policy-doc" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.provisioning_script}"]
    effect    = "Allow"
  }
  
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [
      "${var.lls_admin_password_id}",
      "${var.lls_activation_code_id}"
    ]
    effect    = "Allow"
  }


  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${var.cloudwatch_setup_script}"]
    effect    = "Allow"
  }

  statement {
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions = ["logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
    "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
    effect    = "Allow"
  }

  # add minimal permissions to allow users to connect to instances using Session Manager
  dynamic "statement" {
    for_each = var.aws_ssm_enable ? [1] : []
    content {
      actions = ["ssm:UpdateInstanceInformation",
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"]
      resources = ["*"]
      effect    = "Allow"
    }
  }
}

resource "aws_iam_role_policy" "lls-role-policy" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name   = "${local.prefix}lls_role_policy"
  role   = aws_iam_role.lls-role[0].id
  policy = data.aws_iam_policy_document.lls-policy-doc.json
}

resource "aws_iam_instance_profile" "lls-instance-profile" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name = "${local.prefix}lls_instance_profile"
  role = aws_iam_role.lls-role[0].name
}

resource "aws_cloudwatch_log_group" "instance-log-group" {
  count = var.cloudwatch_enable ? var.instance_count : 0

  name = "${local.prefix}${var.host_name}-${count.index}"
}

resource "time_sleep" "delay_destroy_log_group" {
  depends_on = [aws_cloudwatch_log_group.instance-log-group]

  destroy_duration = "5s"
}

resource "aws_instance" "lls" {
  # wait 5 seconds before deleting the log group to account for delays in 
  # Cloudwatch receiving the last messages before an EC2 instance is shut down
  depends_on = [time_sleep.delay_destroy_log_group]

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
