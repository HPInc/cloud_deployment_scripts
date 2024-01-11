/*
 * Copyright Teradici Corporation 2020-2022;  © Copyright 2022-2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  # Windows computer names must be <= 15 characters, minus 4 chars for "-xyz"
  # where xyz is number of instances (0-999)
  host_name = substr("${local.prefix}${var.instance_name}", 0, 11)

  provisioning_script = "centos-gfx-provisioning.sh"
}

resource "aws_s3_object" "centos-gfx-provisioning-script" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  key    = local.provisioning_script
  bucket = var.bucket_name
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      ad_service_account_password_id = var.ad_service_account_password_id,
      ad_service_account_username    = var.ad_service_account_username,
      aws_region                     = var.aws_region,
      aws_ssm_enable                 = var.aws_ssm_enable,
      bucket_name                    = var.bucket_name,
      cloudwatch_enable              = var.cloudwatch_enable,
      cloudwatch_setup_script        = var.cloudwatch_setup_script,
      domain_controller_ip           = var.domain_controller_ip,
      domain_name                    = var.domain_name,
      nvidia_driver_url              = var.nvidia_driver_url,
      pcoip_registration_code_id     = var.pcoip_registration_code_id,
      teradici_download_token        = var.teradici_download_token,

      auto_logoff_cpu_utilization                = var.auto_logoff_cpu_utilization,
      auto_logoff_enable                         = var.auto_logoff_enable,
      auto_logoff_minutes_idle_before_logoff     = var.auto_logoff_minutes_idle_before_logoff,
      auto_logoff_polling_interval_minutes       = var.auto_logoff_polling_interval_minutes,
      idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization,
      idle_shutdown_enable                       = var.idle_shutdown_enable,
      idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown,
      idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes,
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

resource "aws_iam_role" "centos-gfx-role" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name               = "${local.prefix}centos_gfx_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_iam_policy_document" "centos-gfx-policy-doc" {
  statement {
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [
      "${var.pcoip_registration_code_id}",
      "${var.ad_service_account_password_id}"
    ]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.provisioning_script}"]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${var.cloudwatch_setup_script}"]
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

resource "aws_iam_role_policy" "centos-gfx-role-policy" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name   = "${local.prefix}centos_gfx_role_policy"
  role   = aws_iam_role.centos-gfx-role[0].id
  policy = data.aws_iam_policy_document.centos-gfx-policy-doc.json
}

resource "aws_iam_instance_profile" "centos-gfx-instance-profile" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name = "${local.prefix}centos_gfx_instance_profile"
  role = aws_iam_role.centos-gfx-role[0].name
}

resource "aws_cloudwatch_log_group" "instance-log-group" {
  count = var.cloudwatch_enable ? var.instance_count : 0

  name = "${local.host_name}-${count.index}"
}

resource "time_sleep" "delay_destroy_log_group" {
  depends_on = [aws_cloudwatch_log_group.instance-log-group]

  destroy_duration = "5s"
}

resource "aws_instance" "centos-gfx" {
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

resource "aws_cloudwatch_dashboard" "main" {
  count = var.cloudwatch_enable ? var.instance_count : 0

  dashboard_name = "${local.host_name}-${count.index}"

  dashboard_body = <<EOF
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "CPU Utilization (%)",
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "InstanceId", "${aws_instance.centos-gfx[count.index].id}"]
                ],
                "view": "timeSeries",
                "stat": "Average",
                "period": 300,
                "stacked": false
            }
        },
        {
            "type": "log",
            "x": 12,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Latency (ms)",
                "query": "SOURCE '${local.host_name}-${count.index}' | filter @message like /round trip/ | parse @message 'Tx thread info: round trip time (ms) = *, variance' as rtt | stats pct(rtt, 50), pct(rtt, 80), pct(rtt, 90) by bin(10m)",
                "view": "timeSeries"
            }
        }, 
        {
            "type": "log",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "TxLoss (%)",
                "query": "SOURCE '${local.host_name}-${count.index}' | filter @message like /Loss=/ | parse @message '(A/I/O) Loss=*%/*% (R/T)' as RxLoss, TxLoss | stats pct(TxLoss, 90), pct(TxLoss, 95) by bin(2m)",
                "view": "timeSeries"
            }
        },
        {
            "type": "log",
            "x": 12,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "RxLoss (%)",
                "query": "SOURCE '${local.host_name}-${count.index}' | filter @message like /Loss=/ | parse @message '(A/I/O) Loss=*%/*% (R/T)' as RxLoss, TxLoss | stats pct(RxLoss, 90), pct(RxLoss, 95) by bin(2m)",
                "view": "timeSeries"
            }
        },
        {
            "type": "log",
            "x": 0,
            "y": 12,
            "width": 12,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Data Transmitted (MiB)",
                "query": "SOURCE '${local.host_name}-${count.index}' | filter @message like /MGMT_PCOIP_DATA :Tx thread info: bw limit/ | parse @message 'MGMT_PCOIP_DATA :Tx thread info: bw limit = *, avg tx = *, avg rx = * (kbit' as bwlimit, avgtx, avgrx | stats sum(avgtx)*60/8/1024 as Transmit_MiB by bin(10m)",
                "view": "timeSeries"
            }
        },
        {
            "type": "log",
            "x": 12,
            "y": 12,
            "width": 12,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Data Reveived (MiB)",
                "query": "SOURCE '${local.host_name}-${count.index}' | filter @message like /MGMT_PCOIP_DATA :Tx thread info: bw limit/ | parse @message 'MGMT_PCOIP_DATA :Tx thread info: bw limit = *, avg tx = *, avg rx = * (kbit' as bwlimit, avgtx, avgrx | stats sum(avgrx)*60/8/1024 as Reveive_MiB by bin(10m)",
                "view": "timeSeries"
            }
        }
    ]
}
EOF
}
