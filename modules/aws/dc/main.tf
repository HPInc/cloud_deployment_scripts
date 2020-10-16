/*
 * Copyright (c) 2020 Teradici Corporation
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

resource "aws_s3_bucket_object" "dc-sysprep-script" {
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
    customer_master_key_id   = var.customer_master_key_id
    domain_name              = var.domain_name
    safe_mode_admin_password = var.safe_mode_admin_password
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
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${local.sysprep_script}"]
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

resource "aws_iam_role_policy" "dc-role-policy" {
  name = "${local.prefix}dc_role_policy"
  role = aws_iam_role.dc-role.id
  policy = data.aws_iam_policy_document.dc-policy-doc.json
}

resource "aws_iam_instance_profile" "dc-instance-profile" {
  name = "${local.prefix}dc_instance_profile"
  role = aws_iam_role.dc-role.name
}

resource "aws_instance" "dc" {
  ami           = data.aws_ami.ami.id
  instance_type = var.instance_type

  root_block_device {
    volume_type = "gp2"
    volume_size = var.disk_size_gb
  }

  subnet_id                   = var.subnet
  private_ip                  = var.private_ip
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

resource "null_resource" "wait-for-reboot" {
  depends_on = [null_resource.run-provisioning-script]
  triggers = {
    id = aws_instance.dc.id
  }

  provisioner "local-exec" {
    # This command is written in such a way that it would work if the 
    # local-exec is either the Command Prompt in Windows or the bash shell 
    # in Linux. Note that it does not work on PowerShell in Windows.
    command = "sleep 15 || timeout /nobreak /t 15"
  }
}

resource "null_resource" "new-domain-admin-user" {
  depends_on = [
    null_resource.upload-scripts,
    null_resource.wait-for-reboot,
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
