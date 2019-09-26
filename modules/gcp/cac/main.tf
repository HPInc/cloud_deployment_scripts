/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix            = var.prefix != "" ? "${var.prefix}-" : ""
  startup_script    = "cac-startup.sh"
  ssl_key_filename  = var.ssl_key == "" ? "" : basename(var.ssl_key)
  ssl_cert_filename = var.ssl_cert == "" ? "" : basename(var.ssl_cert)
}

resource "google_storage_bucket_object" "ssl-key" {
  count = tonumber(var.instance_count) == 0 ? 0 : var.ssl_key == "" ? 0 : 1

  bucket = var.bucket_name
  name   = local.ssl_key_filename
  source = var.ssl_key
}

resource "google_storage_bucket_object" "ssl-cert" {
  count = tonumber(var.instance_count) == 0 ? 0 : var.ssl_cert == "" ? 0 : 1

  bucket = var.bucket_name
  name   = local.ssl_cert_filename
  source = var.ssl_cert
}

resource "google_storage_bucket_object" "startup-script" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  depends_on = [
    google_storage_bucket_object.ssl-key,
    google_storage_bucket_object.ssl-cert,
  ]

  bucket  = var.bucket_name
  name    = local.startup_script
  content = templatefile(
    "${path.module}/${local.startup_script}.tmpl",
    {
      kms_cryptokey_id         = var.kms_cryptokey_id,
      cam_url                  = var.cam_url,
      cac_installer_url        = var.cac_installer_url,
      cac_token                = var.cac_token,
      pcoip_registration_code  = var.pcoip_registration_code,

      domain_controller_ip     = var.domain_controller_ip,
      domain_name              = var.domain_name,
      domain_group             = var.domain_group,
      service_account_username = var.service_account_username,
      service_account_password = var.service_account_password,

      bucket_name = var.bucket_name,
      ssl_key     = local.ssl_key_filename,
      ssl_cert    = local.ssl_cert_filename,
    }
  )
}

resource "google_compute_instance" "cac" {
  count = var.instance_count

  provider     = google
  name         = "${local.prefix}${var.host_name}-${count.index}"
  zone         = var.gcp_zone
  machine_type = var.machine_type

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.disk_image
      type  = "pd-ssd"
      size  = var.disk_size_gb
    }
  }

  network_interface {
    subnetwork = var.subnet
    access_config {
    }
  }

  tags = var.network_tags

  metadata = {
    ssh-keys = "${var.cac_admin_user}:${file(var.cac_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.startup-script[0].output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}
