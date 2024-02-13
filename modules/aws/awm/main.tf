/*
 * Copyright Teradici Corporation 2020-2022;  © Copyright 2022-2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  # Convert bool to iterable collection so it can be used with for_each
  enable_public_ip    = var.enable_public_ip ? [true] : []
  awm_setup_script    = "awm-setup.py"
  provisioning_script = "awm-provisioning.sh"
}

resource "aws_s3_object" "awm-setup-script" {
  bucket = var.bucket_name
  key    = local.awm_setup_script
  source = "${path.module}/${local.awm_setup_script}"
}

resource "aws_s3_object" "awm-provisioning-script" {
  bucket = var.bucket_name
  key    = local.provisioning_script
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      awm_admin_password       = var.awm_admin_password,
      awm_aws_credentials_file = var.awm_aws_credentials_file,
      awm_deployment_sa_file   = var.awm_deployment_sa_file,
      awm_repo_channel         = var.awm_repo_channel,
      awm_setup_script         = local.awm_setup_script,
      aws_region               = var.aws_region,
      aws_ssm_enable           = var.aws_ssm_enable,
      bucket_name              = var.bucket_name,
      cloudwatch_enable        = var.cloudwatch_enable,
      cloudwatch_setup_script  = var.cloudwatch_setup_script,
      customer_master_key_id   = var.customer_master_key_id,
      pcoip_registration_code  = var.pcoip_registration_code,
      teradici_download_token  = var.teradici_download_token,
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

resource "aws_iam_role" "awm-role" {
  name               = "${local.prefix}awm_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_kms_key" "encryption-key" {
  count = var.customer_master_key_id == "" ? 0 : 1

  key_id = var.customer_master_key_id
}

data "aws_iam_policy_document" "awm-policy-doc" {
  statement {
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
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

  statement {
    actions   = ["iam:GetAccessKeyLastUsed"]
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
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.awm_setup_script}"]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${var.awm_aws_credentials_file}"]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${var.awm_deployment_sa_file}"]
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
      actions   = ["kms:Encrypt", "kms:Decrypt"]
      resources = [i.value.arn]
      effect    = "Allow"
    }
  }
}

resource "aws_iam_role_policy" "awm-role-policy" {
  name   = "${local.prefix}awm_role_policy"
  role   = aws_iam_role.awm-role.id
  policy = data.aws_iam_policy_document.awm-policy-doc.json
}

resource "aws_iam_instance_profile" "awm-instance-profile" {
  name = "${local.prefix}awm_instance_profile"
  role = aws_iam_role.awm-role.name
}

resource "aws_cloudwatch_log_group" "instance-log-group" {
  count = var.cloudwatch_enable ? 1 : 0

  name = "${local.prefix}${var.host_name}"
}

resource "time_sleep" "delay_destroy_log_group" {
  depends_on = [aws_cloudwatch_log_group.instance-log-group]

  destroy_duration = "5s"
}

resource "aws_instance" "awm" {
  depends_on = [
    aws_s3_object.awm-setup-script,
    aws_s3_object.awm-provisioning-script,
    # wait 5 seconds before deleting the log group to account for delays in
    # Cloudwatch receiving the last messages before an EC2 instance is shut down
    time_sleep.delay_destroy_log_group
  ]

  subnet_id = var.subnet

  ami           = data.aws_ami.ami.id
  instance_type = var.instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.disk_size_gb
    tags = merge(
      {
        Name = "vol-${var.prefix}-sda1-manager"
      },
      var.common_tags
    )
  }

  associate_public_ip_address = var.enable_public_ip

  vpc_security_group_ids = var.security_group_ids

  key_name = var.admin_ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.awm-instance-profile.name

  user_data = data.template_file.user-data.rendered

  lifecycle {
    ignore_changes = [
      # Ignore changes to user_data, since we only use it when
      # the node initializes and we do not want subsequent
      # enhancements to user_data to cause the node to be replaced
      user_data,
      # Since the DC runs on a standard AWS Windows Server, it's possible that
      # AWS will eventually age out the AMI used to initially deploy the DC,
      # so we ignore AMI changes here
      ami,
      # if the ec2 instance_type is changed from the AWS Console, it will
      # cause terraform to think the ebs_optimized field has changed and
      # the instance will be replaced, so we ignore that field here
      ebs_optimized,
    ]
  }

  tags = merge(
    {
      Name = "${local.prefix}${var.host_name}"
    },
    var.common_tags
  )
}
