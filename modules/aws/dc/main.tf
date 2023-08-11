/*
 * Copyright Teradici Corporation 2020-2022;  © Copyright 2022-2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  # Windows computer names must be <= 15 characters
  host_name                 = substr("${local.prefix}vm-dc", 0, 15)
  dc_provisioning_script    = "dc-provisioning.ps1"
  dc_new_ad_accounts_script = "dc-new-ad-accounts.ps1"
  domain_users_list         = "domain_users_list.csv"
  new_domain_users          = var.domain_users_list == "" ? 0 : 1
  tag_name                  = "Provisioning Status"
  #Tag value to check if the DC provisioning is successful or not
  final_status              = "DC Provisioning Completed"
  # Directories start with "C:..." on Windows; All other OSs use "/" for root.
  is_windows_host           = substr(pathexpand("~"), 0, 1) == "/" ? false : true
}

data "template_file" "user-data" {
  template = file("${path.module}/user-data.ps1.tmpl")

  vars = {
    bucket_name = var.bucket_name,
    file_name   = local.dc_provisioning_script
  }
}

resource "aws_s3_object" "dc_provisioning_script" {
  key    = local.dc_provisioning_script
  bucket = var.bucket_name
  content = templatefile(
    "${path.module}/${local.dc_provisioning_script}.tpl",
    {
      admin_password_id           = var.admin_password_id
      aws_ssm_enable              = var.aws_ssm_enable
      bucket_name                 = var.bucket_name
      cloudwatch_enable           = var.cloudwatch_enable
      cloudwatch_setup_script     = var.cloudwatch_setup_script
      domain_name                 = var.domain_name
      dc_new_ad_accounts_script   = local.dc_new_ad_accounts_script
      tag_name                    = local.tag_name
      ldaps_cert_filename         = var.ldaps_cert_filename
      pcoip_agent_install         = var.pcoip_agent_install
      pcoip_agent_version         = var.pcoip_agent_version
      pcoip_registration_code_id  = var.pcoip_registration_code_id
      safe_mode_admin_password_id = var.safe_mode_admin_password_id
      teradici_download_token     = var.teradici_download_token
    }
  )
}

resource "aws_s3_object" "domain_users_list" {

  count   = local.new_domain_users == 1 ? 1 : 0

  key    = local.domain_users_list
  bucket = var.bucket_name
  source = var.domain_users_list
}

resource "aws_s3_object" "dc_new_ad_accounts_script" {
  key    = local.dc_new_ad_accounts_script
  bucket = var.bucket_name
  content = templatefile(
    "${path.module}/${local.dc_new_ad_accounts_script}.tpl",
    {
      domain_name = var.domain_name
      # admin users
      ad_service_account_username     = var.ad_service_account_username
      ad_service_account_password_id  = var.ad_service_account_password_id
      tag_name                        = local.tag_name
      final_status                    = local.final_status

      # domain users
      csv_file = local.new_domain_users == 1 ? local.domain_users_list : ""
      bucket_name                       = var.bucket_name
  })
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

resource "aws_iam_role" "dc-role" {
  name               = "${local.prefix}dc_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_iam_policy_document" "dc-policy-doc" {
  statement {
  # Add permissions to allow retrieval of DC status using tags.
    actions   = [
      "ec2:DescribeTags",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeInstances",
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = [
    "arn:aws:s3:::${var.bucket_name}/${local.dc_provisioning_script}", 
    "arn:aws:s3:::${var.bucket_name}/${local.dc_new_ad_accounts_script}",
    "arn:aws:s3:::${var.bucket_name}/${local.domain_users_list}",
    ]
    effect    = "Allow"
  }

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [
      "${var.pcoip_registration_code_id}",
      "${var.ad_service_account_password_id}",
      "${var.safe_mode_admin_password_id}",
      "${var.admin_password_id}"
    ]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${var.cloudwatch_setup_script}"]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${var.ldaps_cert_filename}"]
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

resource "aws_iam_role_policy" "dc-role-policy" {
  name   = "${local.prefix}dc_role_policy"
  role   = aws_iam_role.dc-role.id
  policy = data.aws_iam_policy_document.dc-policy-doc.json
}

resource "aws_iam_instance_profile" "dc-instance-profile" {
  name = "${local.prefix}dc_instance_profile"
  role = aws_iam_role.dc-role.name
}

resource "aws_cloudwatch_log_group" "instance-log-group" {
  count = var.cloudwatch_enable ? 1 : 0

  name = local.host_name
}

resource "time_sleep" "delay_destroy_log_group" {
  depends_on = [aws_cloudwatch_log_group.instance-log-group]

  destroy_duration = "5s"
}

resource "aws_instance" "dc" {
  depends_on = [
    aws_s3_object.dc_provisioning_script,
    aws_s3_object.dc_new_ad_accounts_script,
    aws_s3_object.domain_users_list,
 
    # wait 5 seconds before deleting the log group to account for delays in
    # Cloudwatch receiving the last messages before an EC2 instance is shut down
    time_sleep.delay_destroy_log_group
  ]

  ami           = data.aws_ami.ami.id
  instance_type = var.instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.disk_size_gb
  }

  subnet_id = var.subnet

  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile = aws_iam_instance_profile.dc-instance-profile.name

  user_data = data.template_file.user-data.rendered

  tags = {
    Name = local.host_name
  }
}

resource "null_resource" "wait_for_DC_to_initialize_windows" {
  count      = local.is_windows_host? 1 : 0
  depends_on = [ aws_instance.dc ]
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = <<-EOT
      $startTime = Get-Date
      $tagValue  = ""
      $instanceId = "${aws_instance.dc.id}"
      while ($tagValue -ne "${local.final_status}") {
        $tagValue = $(aws ec2 describe-tags --region ${var.aws_region} --filters "Name=resource-id,Values=$instanceId" --query "Tags[?Key=='${local.tag_name}'].Value" --output text)  
        if ([string]::IsNullOrEmpty($tagValue)) {
          Write-Host "DC provisioning is starting"
        } else { 
          Write-Host "${local.tag_name}:$tagValue"
        }
        $elapsedTime = New-TimeSpan -Start $startTime -End (Get-Date)
        if ($elapsedTime.TotalMinutes -ge 25) {
          Write-Host "Timeout Error: The DC provisioning process has taken longer than 25 minutes. The DC might be provisioned successfully, 
          but please review CloudWatch Logs for any errors or consider destroying the deployment with 'terraform destroy' and redeploying using 'terraform apply'"
          break  # Exit the loop
        }
        Start-Sleep -Seconds 30
      } 
    EOT   
  }
}

resource "null_resource" "wait_for_DC_to_initialize_linux" {
  count      = local.is_windows_host ? 0 : 1
  depends_on = [ aws_instance.dc ]
  provisioner "local-exec" {
    command = <<-EOT
      startTime=$(date +"%s")
      instanceId="${aws_instance.dc.id}"
      $tagValue  = ""
      while [ "$tagValue" != "${local.final_status}" ]; do
        tagValue=$(aws ec2 describe-tags --region ${var.aws_region} --filters "Name=resource-id,Values=$instanceId" --query "Tags[?Key=='${local.tag_name}'].Value" --output text)
        
        if [ -z "$tagValue" ]; then
          echo "DC provisioning is starting"
        else
          echo "${local.tag_name}:$tagValue"
        fi
        
        elapsedTime=$(($(date +"%s") - startTime))
        
        if [ "$elapsedTime" -ge 1500 ]; then
          echo "Timeout Error: The DC provisioning process has taken longer than 25 minutes. The DC might be provisioned successfully, 
          but please review CloudWatch Logs for any errors or consider destroying the deployment with 'terraform destroy' and redeploying using 'terraform apply'"
          break  # Exit the loop
        fi

        sleep 30
      done
    EOT
  }
}  

