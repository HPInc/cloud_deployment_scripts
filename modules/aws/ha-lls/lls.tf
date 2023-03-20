/*
 * Copyright Teradici Corporation 2020-2022;  © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  lls_host_name           = "${local.prefix}vm-lls"
  lls_provisioning_script = "lls-provisioning.sh"
}

resource "aws_s3_object" "lls-provisioning-script" {
  key    = local.lls_provisioning_script
  bucket = var.bucket_name
  content = templatefile(
    "${path.module}/${local.lls_provisioning_script}.tmpl",
    {
      aws_region              = var.aws_region,
      aws_ssm_enable          = var.aws_ssm_enable,
      bucket_name             = var.bucket_name,
      cloudwatch_enable       = var.cloudwatch_enable,
      cloudwatch_setup_script = var.cloudwatch_setup_script,
      customer_master_key_id  = var.customer_master_key_id,
      haproxy_backup_ip       = var.assigned_ips["haproxy_backup"],
      haproxy_master_ip       = var.assigned_ips["haproxy_master"],
      lls_activation_code     = var.lls_activation_code,
      lls_admin_password      = var.lls_admin_password,
      lls_backup_ip           = var.assigned_ips["lls_backup"],
      lls_license_count       = var.lls_license_count,
      lls_main_ip             = var.assigned_ips["lls_main"],
      teradici_download_token = var.teradici_download_token,
    }
  )
}

data "template_file" "lls-user-data" {
  template = file("${path.module}/user-data.sh.tmpl")

  vars = {
    bucket_name         = var.bucket_name,
    provisioning_script = local.lls_provisioning_script,
  }
}

# Need to do this to look up AMI ID, which is different for each region
data "aws_ami" "lls_ami" {
  most_recent = true
  owners      = [var.lls_ami_owner]

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

  dynamic "statement" {
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
  name   = "${local.prefix}lls_role_policy"
  role   = aws_iam_role.lls-role.id
  policy = data.aws_iam_policy_document.lls-policy-doc.json
}

resource "aws_iam_instance_profile" "lls-instance-profile" {
  name = "${local.prefix}lls_instance_profile"
  role = aws_iam_role.lls-role.name
}

resource "aws_cloudwatch_log_group" "instance-log-group-lls-main" {
  count = var.cloudwatch_enable ? 1 : 0

  name = "${local.prefix}${var.host_name}-main"
}

resource "time_sleep" "delay_destroy_log_group_lls_main" {
  depends_on = [aws_cloudwatch_log_group.instance-log-group-lls-main]

  destroy_duration = "5s"
}

resource "aws_instance" "lls_main" {
  # wait 5 seconds before deleting the log group to account for delays in 
  # Cloudwatch receiving the last messages before an EC2 instance is shut down
  depends_on = [time_sleep.delay_destroy_log_group_lls_main]

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

resource "aws_cloudwatch_log_group" "instance-log-group-lls-backup" {
  count = var.cloudwatch_enable ? 1 : 0

  name = "${local.prefix}${var.host_name}-backup"
}

resource "time_sleep" "delay_destroy_log_group_lls_backup" {
  depends_on = [aws_cloudwatch_log_group.instance-log-group-lls-backup]

  destroy_duration = "5s"
}

resource "aws_instance" "lls_backup" {
  # wait 5 seconds before deleting the log group to account for delays in 
  # Cloudwatch receiving the last messages before an EC2 instance is shut down
  depends_on = [time_sleep.delay_destroy_log_group_lls_backup]

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
