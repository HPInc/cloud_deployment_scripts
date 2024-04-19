/*
 * © Copyright 2022-2024 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  provisioning_script = "awc-provisioning.sh"
  awm_script          = "get-connector-token.py"

  instance_info_list = flatten(
    [for i in range(length(var.zone_list)) :
      [for j in range(var.instance_count_list[i]) :
        {
          zone   = var.zone_list[i],
          subnet = var.subnet_list[i],
        }
      ]
    ]
  )
  tls_key_filename  = var.tls_key == "" ? "" : basename(var.tls_key)
  tls_cert_filename = var.tls_cert == "" ? "" : basename(var.tls_cert)

  awc_log_groups = join("",
    [for i in range(length(local.instance_info_list)) :
      "SOURCE '${aws_cloudwatch_log_group.instance-log-group[i].id}' | "
    ]
  )

  workstation_log_groups = join("",
    [for i in range(var.rocky_gfx_instance_count) :
      "SOURCE '${local.prefix}grock-${i}' | "
    ],
    [for i in range(var.rocky_std_instance_count) :
      "SOURCE '${local.prefix}srock-${i}' | "
    ],
    [for i in range(var.win_gfx_instance_count) :
      "SOURCE '${local.prefix}gwin-${i}' | "
    ],
    [for i in range(var.win_std_instance_count) :
      "SOURCE '${local.prefix}swin-${i}' | "
    ]
  )
}

resource "aws_s3_object" "get-connector-token-script" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  bucket = var.bucket_name
  key    = local.awm_script
  source = "${path.module}/${local.awm_script}"
}

resource "aws_s3_object" "tls-key" {
  count = length(local.instance_info_list) == 0 ? 0 : var.tls_key == "" ? 0 : 1

  bucket = var.bucket_name
  key    = local.tls_key_filename
  source = var.tls_key
}

resource "aws_s3_object" "tls-cert" {
  count = length(local.instance_info_list) == 0 ? 0 : var.tls_cert == "" ? 0 : 1

  bucket = var.bucket_name
  key    = local.tls_cert_filename
  source = var.tls_cert
}

resource "aws_s3_object" "awc-provisioning-script" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  key    = local.provisioning_script
  bucket = var.bucket_name
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      ad_service_account_password_id = var.ad_service_account_password_id,
      ad_service_account_username = var.ad_service_account_username,
      awc_extra_install_flags     = var.awc_extra_install_flags,
      aws_region                  = var.aws_region,
      aws_ssm_enable              = var.aws_ssm_enable,
      bucket_name                 = var.bucket_name,
      awm_deployment_sa_file_id   = var.awm_deployment_sa_file_id,
      awc_flag_manager_insecure   = var.awc_flag_manager_insecure ? "true" : "",
      awm_script                  = local.awm_script,
      manager_url                 = var.manager_url,
      cloudwatch_enable           = var.cloudwatch_enable,
      cloudwatch_setup_script     = var.cloudwatch_setup_script,
      computers_dn                = var.computers_dn,
      domain_controller_ip        = var.domain_controller_ip,
      domain_name                 = var.domain_name,
      ldaps_cert_filename         = var.ldaps_cert_filename,
      lls_ip                      = var.lls_ip,
      tls_cert                    = local.tls_cert_filename,
      tls_key                     = local.tls_key_filename,
      teradici_download_token     = var.teradici_download_token,
      users_dn                    = var.users_dn,
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

resource "aws_iam_role" "awc-role" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  name               = "${local.prefix}awc_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_iam_policy_document" "awc-policy-doc" {
  statement {
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [
      "${var.ad_service_account_password_id}",
      "${var.awm_deployment_sa_file_id}"
    ]
    effect    = "Allow"
  }

  statement {
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::${var.bucket_name}/${local.provisioning_script}",
      "arn:aws:s3:::${var.bucket_name}/${local.awm_script}",
      "arn:aws:s3:::${var.bucket_name}/${var.cloudwatch_setup_script}",
      "arn:aws:s3:::${var.bucket_name}/${var.ldaps_cert_filename}",
    ]
    effect = "Allow"
  }

  # add minimal permissions to allow users to connect to instances using Session Manager
  statement {
    actions = ["ssm:UpdateInstanceInformation",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
    "ssmmessages:OpenDataChannel"]
    resources = ["*"]
    effect    = "Allow"
  }

  dynamic "statement" {
    for_each = aws_s3_object.tls-key
    iterator = i
    content {
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::${var.bucket_name}/${local.tls_key_filename}"]
      effect    = "Allow"
    }
  }

  dynamic "statement" {
    for_each = aws_s3_object.tls-cert
    iterator = i
    content {
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::${var.bucket_name}/${local.tls_cert_filename}"]
      effect    = "Allow"
    }
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
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

resource "aws_iam_role_policy" "awc-role-policy" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  name   = "${local.prefix}awc_role_policy"
  role   = aws_iam_role.awc-role[0].id
  policy = data.aws_iam_policy_document.awc-policy-doc.json
}

resource "aws_iam_instance_profile" "awc-instance-profile" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  name = "${local.prefix}awc_instance_profile"
  role = aws_iam_role.awc-role[0].name
}

resource "aws_cloudwatch_log_group" "instance-log-group" {
  count = var.cloudwatch_enable ? length(local.instance_info_list) : 0

  name = "${local.prefix}${var.host_name}-${count.index}"
}

resource "time_sleep" "delay_destroy_log_group" {
  depends_on = [aws_cloudwatch_log_group.instance-log-group]

  destroy_duration = "5s"
}

resource "aws_instance" "awc" {
  count = length(local.instance_info_list)

  depends_on = [
    aws_s3_object.tls-key,
    aws_s3_object.tls-cert,
    aws_s3_object.get-connector-token-script,
    aws_s3_object.awc-provisioning-script,
    # wait 5 seconds before deleting the log group to account for delays in
    # Cloudwatch receiving the last messages before an EC2 instance is shut down
    time_sleep.delay_destroy_log_group
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

  iam_instance_profile = aws_iam_instance_profile.awc-instance-profile[0].name

  user_data = data.template_file.user-data.rendered

  tags = {
    Name = "${local.prefix}${var.host_name}-${count.index}"
  }
}

resource "aws_cloudwatch_dashboard" "awc" {
  count = var.cloudwatch_enable ? length(local.instance_info_list) : 0

  dashboard_name = "${local.prefix}${var.host_name}-${count.index}"

  dashboard_body = <<EOF
{
    "widgets": [
        {
            "type": "log",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Active Connections",
                "query": "SOURCE '${aws_cloudwatch_log_group.instance-log-group[count.index].id}' | filter @message like /get_statistics returning/ | parse @message '* get_statistics returning * UDP connections currently working' as m, num | stats latest(num) as NumberOfConnections by bin(20m) as connection_num | sort connection_num",
                "view": "bar"
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
                "title": "User Login History",
                "query": "SOURCE '${aws_cloudwatch_log_group.instance-log-group[count.index].id}' | filter @message like /User authenticated successfully/ | parse @message '<broker-info><product-name>PCoIP*Agent for*<hostname>*</hostname>*<username>*</username>' as a, b, hostname, c, username | display username, hostname, @timestamp",
                "view": "table"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 8,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "CPU Utilization (%)",
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "InstanceId", "${aws_instance.awc[count.index].id}"]
                ],
                "view": "timeSeries",
                "stat": "Average",
                "period": 300,
                "stacked": false
            }
        },
        {
            "type": "metric",
            "x": 8,
            "y": 6,
            "width": 8,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Network in (bytes)",
                "metrics": [
                    [ "AWS/EC2", "NetworkIn", "InstanceId", "${aws_instance.awc[count.index].id}"]
                ],
                "view": "timeSeries",
                "stat": "Average",
                "period": 300,
                "stacked": false
            }
        },
        {
            "type": "metric",
            "x": 16,
            "y": 6,
            "width": 8,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Network out (bytes)",
                "metrics": [
                    [ "AWS/EC2", "NetworkOut", "InstanceId", "${aws_instance.awc[count.index].id}"]
                ],
                "view": "timeSeries",
                "stat": "Average",
                "period": 300,
                "stacked": false
            }
        }
    ]
}
EOF
}

resource "aws_cloudwatch_dashboard" "overall" {
  count = var.cloudwatch_enable ? 1 : 0

  dashboard_name = "${local.prefix}overall"

  dashboard_body = <<EOF
{
    "widgets": [
        {
            "type": "log",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Number of Users in AD",
                "query": "SOURCE '${aws_cloudwatch_log_group.instance-log-group[0].id}' | filter @message like /Users in local cache/ | parse @message '* [*] ActiveDirectorySync Found * users in active directory using' as time, type, num | stats latest(num) as NumberOfUsers by bin(20m) as user_num | sort user_num",
                "view": "bar"
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
                "title": "Number of Machines in AD",
                "query": "SOURCE '${aws_cloudwatch_log_group.instance-log-group[0].id}' | filter @message like /Machines in local cache/ | parse @message '* [*] ActiveDirectorySync Found * ActiveDirectorySync Found * machines in active directory' as time, type, user, num | stats latest(num) as NumberOfMachines by bin(20m) as machine_num| sort machine_num",
                "view": "bar"
            }
        },
        {
            "type": "log",
            "x": 0,
            "y": 6,
            "width": 6,
            "height": 4,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Active Connections",
                "query": "${local.awc_log_groups}filter @message like /get_statistics returning/ | parse @message '* get_statistics returning * UDP connections currently working' as m, num | parse @log '*:*' as account_id, connector | stats latest(num) as NumberOfConnections by connector | sort NumberOfConnections desc",
                "view": "table"
            }
        },
        {
            "type": "log",
            "x": 6,
            "y": 6,
            "width": 6,
            "height": 4,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Top 5 PCoIP Agent Latency",
                "query": "${local.workstation_log_groups}filter @message like /round trip/ | parse @message 'Tx thread info: round trip time (ms) = *, variance' as rtt | parse @log '*:*' as account_id, workstation | stats concat(ceil(avg(rtt)), 'ms') as RoundTripLatency by workstation | sort RoundTripLatency desc | limit 5",
                "view": "table"
            }
        },
        {
            "type": "log",
            "x": 12,
            "y": 6,
            "width": 6,
            "height": 4,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Top 5 PCoIP Agent Data Transmitted",
                "query": "${local.workstation_log_groups}filter @message like /MGMT_PCOIP_DATA :Tx thread info: bw limit/ | parse @message 'MGMT_PCOIP_DATA :Tx thread info: bw limit = *, avg tx = *, avg rx = * (kbit' as bwlimit, avgtx, avgrx  | parse @log '*:*' as account_id, workstation | stats concat(ceil(sum(avgtx)*60/8/1024), 'MiB') as Transmitted by workstation | sort Transmitted desc | limit 5",
                "view": "table"
            }
        },
        {
            "type": "log",
            "x": 18,
            "y": 6,
            "width": 6,
            "height": 4,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Top 5 PCoIP Agent Data Received",
                "query": "${local.workstation_log_groups}filter @message like /MGMT_PCOIP_DATA :Tx thread info: bw limit/ | parse @message 'MGMT_PCOIP_DATA :Tx thread info: bw limit = *, avg tx = *, avg rx = * (kbit' as bwlimit, avgtx, avgrx  | parse @log '*:*' as account_id, workstation | stats concat(ceil(sum(avgrx)*60/8/1024), 'MiB') as Received by workstation | sort Received desc | limit 5",
                "view": "table"
            }
        },
        {
            "type": "log",
            "x": 0,
            "y": 12,
            "width": 6,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Top 10 PCoIP Agent Packet Loss (Received)",
                "query": "${local.workstation_log_groups}filter @message like /Loss=/ | parse @message '(A/I/O) Loss=*%/*% (R/T)' as rxloss, txloss | parse @log '*:*' as account_id, workstation | stats concat(avg(sum(rxloss)), '%') as RxLoss by workstation | sort RxLoss desc | limit 10",
                "view": "table"
            }
        },
        {
            "type": "log",
            "x": 6,
            "y": 12,
            "width": 6,
            "height": 6,
            "properties": {
                "region": "${var.aws_region}",
                "title": "Top 10 PCoIP Agent Packet Loss (Transmitted)",
                "query": "${local.workstation_log_groups}filter @message like /Loss=/ | parse @message '(A/I/O) Loss=*%/*% (R/T)' as rxloss, txloss | parse @log '*:*' as account_id, workstation | stats concat(avg(sum(txloss)), '%') as TxLoss by workstation | sort TxLoss desc | limit 10",
                "view": "table"
            }
        }
    ]
}
EOF
}
