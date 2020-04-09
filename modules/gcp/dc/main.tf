/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  # Windows computer names must be <= 15 characters
  host_name                  = substr("${local.prefix}vm-dc", 0, 15)
  sysprep_filename           = "dc-sysprep.ps1"
  provisioning_file          = "C:/Temp/dc-provisioning.ps1"
  new_domain_admin_user_file = "C:/Temp/new_domain_admin_user.ps1"
  new_domain_users_file      = "C:/Temp/new_domain_users.ps1"
  domain_users_list_file     = "C:/Temp/domain_users_list.csv"
  new_domain_users           = var.domain_users_list == "" ? 0 : 1
  admin_password = var.kms_cryptokey_id == "" ? var.admin_password : data.google_kms_secret.decrypted_admin_password[0].plaintext
}

resource "google_storage_bucket_object" "dc-sysprep-script" {
  bucket  = var.bucket_name
  name    = local.sysprep_filename
  content = templatefile(
    "${path.module}/${local.sysprep_filename}.tmpl",
    {
      kms_cryptokey_id = var.kms_cryptokey_id,
      admin_password   = var.admin_password,
    }
  )
}

data "template_file" "dc-provisioning-script" {
  template = file("${path.module}/dc-provisioning.ps1.tpl")

  vars = {
    kms_cryptokey_id         = var.kms_cryptokey_id
    domain_name              = var.domain_name
    safe_mode_admin_password = var.safe_mode_admin_password
  }
}

data "template_file" "new-domain-admin-user-script" {
  template = file("${path.module}/new_domain_admin_user.ps1.tpl")

  vars = {
    kms_cryptokey_id = var.kms_cryptokey_id
    host_name        = local.host_name
    domain_name      = var.domain_name
    account_name     = var.ad_service_account_username
    account_password = var.ad_service_account_password
  }
}

data "template_file" "new-domain-users-script" {
  template = file("${path.module}/new_domain_users.ps1.tpl")

  vars = {
    domain_name = var.domain_name
    csv_file    = local.domain_users_list_file
  }
}

data "google_kms_secret" "decrypted_admin_password" {
  count = var.kms_cryptokey_id == "" ? 0 : 1

  crypto_key = var.kms_cryptokey_id
  ciphertext = var.admin_password
}

resource "google_compute_instance" "dc" {
  provider     = google
  name         = local.host_name
  zone         = var.gcp_zone
  machine_type = var.machine_type

  boot_disk {
    initialize_params {
      image = var.disk_image
      type  = "pd-ssd"
      size  = var.disk_size_gb
    }
  }

  network_interface {
    subnetwork = var.subnet
    network_ip = var.private_ip
    access_config {
    }
  }

  tags = var.network_tags

  metadata = {
    sysprep-specialize-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.dc-sysprep-script.output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}

resource "null_resource" "upload-scripts" {
  depends_on = [google_compute_instance.dc]
  triggers = {
    instance_id = google_compute_instance.dc.instance_id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = local.admin_password
    host     = google_compute_instance.dc.network_interface[0].access_config[0].nat_ip
    port     = "5986"
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

  depends_on = [google_compute_instance.dc]
  triggers = {
    instance_id = google_compute_instance.dc.instance_id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = local.admin_password
    host     = google_compute_instance.dc.network_interface[0].access_config[0].nat_ip
    port     = "5986"
    https    = true
    insecure = true
  }

  provisioner "file" {
    source      = "domain_users_list.csv"
    destination = local.domain_users_list_file
  }
}

resource "null_resource" "run-provisioning-script" {
  depends_on = [null_resource.upload-scripts]
  triggers = {
    instance_id = google_compute_instance.dc.instance_id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = local.admin_password
    host     = google_compute_instance.dc.network_interface[0].access_config[0].nat_ip
    port     = "5986"
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
    instance_id = google_compute_instance.dc.instance_id
  }

  provisioner "local-exec" {
    # This command is written this way to make it work regardless of whether the
    # user runs Terraform in Windows (where local-exec is the command prompt) or
    # Linux (where the local-exec is e.g. bash shell).
    command = "sleep 15 || powershell sleep 15"
  }
}

resource "null_resource" "new-domain-admin-user" {
  depends_on = [
    null_resource.upload-scripts,
    null_resource.wait-for-reboot,
  ]
  triggers = {
    instance_id = google_compute_instance.dc.instance_id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = local.admin_password
    host     = google_compute_instance.dc.network_interface[0].access_config[0].nat_ip
    port     = "5986"
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
    instance_id = google_compute_instance.dc.instance_id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = local.admin_password
    host     = google_compute_instance.dc.network_interface[0].access_config[0].nat_ip
    port     = "5986"
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
