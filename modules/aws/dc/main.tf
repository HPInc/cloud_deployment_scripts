/*
 * Copyright Teradici Corporation 2020-2021;  © Copyright 2021-2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  # Windows computer names must be <= 15 characters
  host_name                  = substr("${local.prefix}vm-dc", 0, 15)
  provisioning_file          = "C:/Temp/provisioning.ps1"
  new_domain_admin_user_file = "C:/Temp/new_domain_admin_user.ps1"
  new_domain_users_file      = "C:/Temp/new_domain_users.ps1"
  domain_users_list_file     = "C:/Temp/domain_users_list.csv"
  new_domain_users           = var.domain_users_list == "" ? 0 : 1
  sysprep_script             = "dc-sysprep.ps1"
  admin_password = var.customer_master_key_id == "" ? var.admin_password : data.aws_kms_secrets.decrypted_secrets[0].plaintext["admin_password"]
}

data "aws_kms_secrets" "decrypted_secrets" {
  count = var.customer_master_key_id == "" ? 0 : 1

  secret {
    name    = "admin_password"
    payload = var.admin_password
  }
}

resource "aws_s3_object" "dc-sysprep-script" {
  key     = local.sysprep_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.sysprep_script}.tmpl",
    {
      customer_master_key_id = var.customer_master_key_id
      admin_password         = var.admin_password
      hostname               = local.host_name
    }
  )
}

data "template_file" "user-data" {
  template = file("${path.module}/user-data.ps1.tmpl")

  vars = {
    bucket_name = var.bucket_name,
    file_name   = local.sysprep_script,
  }
}

data "template_file" "dc-provisioning-script" {
  template = file("${path.module}/dc-provisioning.ps1.tpl")

  vars = {
    aws_ssm_enable           = var.aws_ssm_enable
    bucket_name              = var.bucket_name
    cloudwatch_enable        = var.cloudwatch_enable
    cloudwatch_setup_script  = var.cloudwatch_setup_script
    customer_master_key_id   = var.customer_master_key_id
    domain_name              = var.domain_name
    ldaps_cert_filename      = var.ldaps_cert_filename
    pcoip_agent_version      = var.pcoip_agent_version
    pcoip_registration_code  = var.pcoip_registration_code
    safe_mode_admin_password = var.safe_mode_admin_password
    teradici_download_token  = var.teradici_download_token
  }
}

data "template_file" "new-domain-admin-user-script" {
  template = file("${path.module}/new_domain_admin_user.ps1.tpl")

  vars = {
    customer_master_key_id = var.customer_master_key_id
    host_name              = local.host_name
    domain_name            = var.domain_name
    account_name           = var.ad_service_account_username
    account_password       = var.ad_service_account_password
  }
}

data "template_file" "new-domain-users-script" {
  template = file("${path.module}/new_domain_users.ps1.tpl")

  vars = {
    domain_name = var.domain_name
    csv_file    = local.domain_users_list_file
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

resource "aws_iam_role" "dc-role" {
  name               = "${local.prefix}dc_role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy-doc.json
}

data "aws_kms_key" "encryption-key" {
  count = var.customer_master_key_id == "" ? 0 : 1

  key_id = var.customer_master_key_id
}

data "aws_iam_policy_document" "dc-policy-doc" {
  statement {
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.sysprep_script}"]
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
    actions   = ["logs:CreateLogGroup",
                 "logs:CreateLogStream",
                 "logs:DescribeLogStreams",
                 "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
    effect    = "Allow"
  }

  # add minimal permissions to allow users to connect to instances using Session Manager
  dynamic statement {
    for_each = var.aws_ssm_enable ? [1] : []
    content {
      actions   = ["ssm:UpdateInstanceInformation",
                  "ssmmessages:CreateControlChannel",
                  "ssmmessages:CreateDataChannel",
                  "ssmmessages:OpenControlChannel",
                  "ssmmessages:OpenDataChannel"]
      resources = ["*"]
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

resource "aws_iam_role_policy" "dc-role-policy" {
  name = "${local.prefix}dc_role_policy"
  role = aws_iam_role.dc-role.id
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
  # wait 5 seconds before deleting the log group to account for delays in 
  # Cloudwatch receiving the last messages before an EC2 instance is shut down
  depends_on = [time_sleep.delay_destroy_log_group]
  
  ami           = data.aws_ami.ami.id
  instance_type = var.instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.disk_size_gb
  }

  subnet_id                   = var.subnet
  associate_public_ip_address = true

  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile = aws_iam_instance_profile.dc-instance-profile.name

  user_data = data.template_file.user-data.rendered

  tags = {
    Name = local.host_name
  }
}

resource "null_resource" "upload-scripts" {
  depends_on = [aws_instance.dc]

  triggers = {
    id = aws_instance.dc.id
  }

/* Occasionally application of this resource may fail with an error along the
   lines of "dial tcp <DC public IP>:5986: i/o timeout". A potential cause of
   this is when the sysprep script has not quite finished running to set up
   WinRM on the DC host in time for this step to connect. Increasing the timeout
   from the default 5 minutes is intended to work around this scenario.
*/
  connection {
    type     = "winrm"
    user     = "Administrator"
    password = local.admin_password
    host     = aws_instance.dc.public_ip
    port     = 5986
    https    = true
    insecure = true
    timeout  = "10m"
  }

  provisioner "file" {
    content     = data.template_file.dc-provisioning-script.rendered
    destination = local.provisioning_file
  }

  provisioner "file" {
    content     = data.template_file.new-domain-admin-user-script.rendered
    destination = local.new_domain_admin_user_file
  }

  provisioner "file" {
    content     = data.template_file.new-domain-users-script.rendered
    destination = local.new_domain_users_file
  }
}

resource "null_resource" "upload-domain-users-list" {
  count = local.new_domain_users

  depends_on = [aws_instance.dc]
  triggers = {
    id = aws_instance.dc.id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = local.admin_password
    host     = aws_instance.dc.public_ip
    port     = 5986
    https    = true
    insecure = true
  }

  provisioner "file" {
    source      = var.domain_users_list
    destination = local.domain_users_list_file
  }
}

resource "null_resource" "run-provisioning-script" {
  depends_on = [null_resource.upload-scripts]
  triggers = {
    id = aws_instance.dc.id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = local.admin_password
    host     = aws_instance.dc.public_ip
    port     = 5986
    https    = true
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell -file ${local.provisioning_file}",
      "del ${replace(local.provisioning_file, "/", "\\")}",
    ]
  }
}

resource "time_sleep" "wait-for-reboot" {
  depends_on = [null_resource.run-provisioning-script]
  triggers = {
    id = aws_instance.dc.id
  }
  create_duration = "15s"
}

resource "null_resource" "new-domain-admin-user" {
  depends_on = [
    null_resource.upload-scripts,
    time_sleep.wait-for-reboot,
  ]
  triggers = {
    id = aws_instance.dc.id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = local.admin_password
    host     = aws_instance.dc.public_ip
    port     = 5986
    https    = true
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell -file ${local.new_domain_admin_user_file}",
      "del ${replace(local.new_domain_admin_user_file, "/", "\\")}",
    ]
  }
}

resource "null_resource" "new-domain-user" {
  count = local.new_domain_users

  # Waits for new-domain-admin-user because that script waits for ADWS to be up
  depends_on = [
    null_resource.upload-domain-users-list,
    null_resource.new-domain-admin-user,
  ]

  triggers = {
    id = aws_instance.dc.id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = local.admin_password
    host     = aws_instance.dc.public_ip
    port     = 5986
    https    = true
    insecure = true
  }

  provisioner "remote-exec" {
    # wait in case csv file is newly uploaded
    inline = [
      "powershell sleep 2",
      "powershell -file ${local.new_domain_users_file}",
      "del ${replace(local.new_domain_users_file, "/", "\\")}",
      "del ${replace(local.domain_users_list_file, "/", "\\")}",
    ]
  }
}
