/*
 * Copyright Teradici Corporation 2020-2022;  © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  haproxy_host_name               = "${local.prefix}vm-haproxy"
  haproxy_provisioning_script     = "haproxy-provisioning.sh"
  haproxy_config                  = "haproxy.cfg"
  keepalived_config               = "keepalived.cfg"
  keepalived_notify_master_script = "notify_master.sh"
}

resource "aws_s3_bucket_object" "haproxy-provisioning-script" {
  key     = local.haproxy_provisioning_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.haproxy_provisioning_script}.tmpl",
    {
      aws_region              = var.aws_region, 
      bucket_name             = var.bucket_name,
      cloudwatch_enable       = var.cloudwatch_enable,
      cloudwatch_setup_script = var.cloudwatch_setup_script,
      haproxy_backup_ip       = var.assigned_ips["haproxy_backup"],
      haproxy_config          = local.haproxy_config,
      haproxy_master_ip       = var.assigned_ips["haproxy_master"],
      haproxy_vip             = var.assigned_ips["haproxy_vip"],
      haproxy_vip_cidr        = "${var.assigned_ips["haproxy_vip"]}${var.assigned_ips["subnet_mask"]}",
      keepalived_config       = local.keepalived_config,
      lls_backup_ip           = var.assigned_ips["lls_backup"],
      lls_main_ip             = var.assigned_ips["lls_main"],
      notify_master           = local.keepalived_notify_master_script,
    }
  )
}

resource "aws_s3_bucket_object" "haproxy-config" {
  key     = local.haproxy_config
  bucket  = var.bucket_name
  content = file("${path.module}/${local.haproxy_config}")
}

resource "aws_s3_bucket_object" "keepalived-config" {
  key     = local.keepalived_config
  bucket  = var.bucket_name
  content = file("${path.module}/${local.keepalived_config}")
}

resource "aws_s3_bucket_object" "keepalived-notify-master-script" {
  key     = local.keepalived_notify_master_script
  bucket  = var.bucket_name
  content = file("${path.module}/${local.keepalived_notify_master_script}")
}

data "template_file" "haproxy-user-data" {
  template = file("${path.module}/user-data.sh.tmpl")

  vars = {
    bucket_name         = var.bucket_name,
    provisioning_script = local.haproxy_provisioning_script,
  }
}

# Need to do this to look up AMI ID, which is different for each region
data "aws_ami" "haproxy_ami" {
  most_recent = true
  owners      = [var.haproxy_ami_owner]

  filter {
    name   = "name"
    values = [var.haproxy_ami_name]
  }
}

resource "aws_iam_role" "haproxy-role" {
  name               = "${local.prefix}haproxy_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_iam_policy_document" "haproxy-policy-doc" {
  statement {
    actions   = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::${var.bucket_name}/${local.haproxy_provisioning_script}",
      "arn:aws:s3:::${var.bucket_name}/${local.haproxy_config}",
      "arn:aws:s3:::${var.bucket_name}/${local.keepalived_config}",
      "arn:aws:s3:::${var.bucket_name}/${local.keepalived_notify_master_script}",
    ]
    effect    = "Allow"
  }

  statement {
    actions   = ["ec2:AssignPrivateIpAddresses"]      
    resources = ["*"]
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
    actions   = ["logs:CreateLogGroup",
                 "logs:CreateLogStream",
                 "logs:DescribeLogStreams",
                 "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
    effect    = "Allow"
  }
  
  # add minimal permissions to allow users to connect to instances using Session Manager
  statement {
    actions   = ["ssm:UpdateInstanceInformation",
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"]
    resources = ["*"]
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

resource "aws_iam_role_policy" "haproxy-role-policy" {
  name = "${local.prefix}haproxy_role_policy"
  role = aws_iam_role.haproxy-role.id
  policy = data.aws_iam_policy_document.haproxy-policy-doc.json
}

resource "aws_iam_instance_profile" "haproxy-instance-profile" {
  name = "${local.prefix}haproxy_instance_profile"
  role = aws_iam_role.haproxy-role.name
}

resource "aws_cloudwatch_log_group" "instance-log-group-ha-master" {
  count = var.cloudwatch_enable ? 1 : 0

  name = "${local.haproxy_host_name}-master"
}

resource "time_sleep" "delay_destroy_log_group_master" {
  depends_on = [aws_cloudwatch_log_group.instance-log-group-ha-master]

  destroy_duration = "5s"
}

resource "aws_instance" "haproxy_master" {
  # wait 5 seconds before deleting the log group to account for delays in 
  # Cloudwatch receiving the last messages before an EC2 instance is shut down
  depends_on = [time_sleep.delay_destroy_log_group_master]

  ami           = data.aws_ami.haproxy_ami.id
  instance_type = var.haproxy_instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.haproxy_disk_size_gb
  }

  subnet_id  = var.subnet
  private_ip = var.assigned_ips["haproxy_master"]

  vpc_security_group_ids = var.security_group_ids

  key_name = var.admin_ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.haproxy-instance-profile.name

  user_data = data.template_file.haproxy-user-data.rendered

  tags = {
    Name = "${local.haproxy_host_name}-master"
  }
}

resource "aws_cloudwatch_log_group" "instance-log-group-ha-backup" {
  count = var.cloudwatch_enable ? 1 : 0
  
  name = "${local.haproxy_host_name}-backup"
}

resource "time_sleep" "delay_destroy_log_group_backup" {
  depends_on = [aws_cloudwatch_log_group.instance-log-group-ha-backup]

  destroy_duration = "5s"
}

resource "aws_instance" "haproxy_backup" {
  # wait 5 seconds before deleting the log group to account for delays in 
  # Cloudwatch receiving the last messages before an EC2 instance is shut down
  depends_on = [time_sleep.delay_destroy_log_group_backup]

  ami           = data.aws_ami.haproxy_ami.id
  instance_type = var.haproxy_instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.haproxy_disk_size_gb
  }

  subnet_id  = var.subnet
  private_ip = var.assigned_ips["haproxy_backup"]


  vpc_security_group_ids = var.security_group_ids

  key_name = var.admin_ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.haproxy-instance-profile.name

  user_data = data.template_file.haproxy-user-data.rendered

  tags = {
    Name = "${local.haproxy_host_name}-backup"
  }
}
