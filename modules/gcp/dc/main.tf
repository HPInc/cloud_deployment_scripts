/*
 * Copyright Teradici Corporation 2019-2021;  © Copyright 2022 HP Development Company, L.P.
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
  admin_password             = var.kms_cryptokey_id == "" ? var.admin_password : data.google_kms_secret.decrypted_admin_password[0].plaintext
}

resource "google_storage_bucket_object" "dc-sysprep-script" {
  bucket = var.bucket_name
  name   = local.sysprep_filename
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
    bucket_name              = var.bucket_name
    domain_name              = var.domain_name
    gcp_ops_agent_enable     = var.gcp_ops_agent_enable
    kms_cryptokey_id         = var.kms_cryptokey_id
    ldaps_cert_filename      = var.ldaps_cert_filename
    ops_setup_script         = var.ops_setup_script
    pcoip_agent_install      = var.pcoip_agent_install
    pcoip_agent_version      = var.pcoip_agent_version
    pcoip_registration_code  = var.pcoip_registration_code
    safe_mode_admin_password = var.safe_mode_admin_password
    teradici_download_token  = var.teradici_download_token
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

  enable_display = true

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
    email  = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}

resource "null_resource" "upload-scripts" {
  depends_on = [google_compute_instance.dc]
  triggers = {
    instance_id = google_compute_instance.dc.instance_id
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
    host     = google_compute_instance.dc.network_interface[0].access_config[0].nat_ip
    port     = "5986"
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
    source      = var.domain_users_list
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

resource "time_sleep" "wait-for-reboot" {
  depends_on = [null_resource.run-provisioning-script]
  triggers = {
    instance_id = google_compute_instance.dc.instance_id
  }
  create_duration = "15s"
}

resource "null_resource" "new-domain-admin-user" {
  depends_on = [
    null_resource.upload-scripts,
    time_sleep.wait-for-reboot,
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
