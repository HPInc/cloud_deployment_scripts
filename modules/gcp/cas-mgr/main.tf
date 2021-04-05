/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  # Convert bool to iterable collection so it can be used with for_each
  enable_public_ip = var.enable_public_ip ? [true] : []
  cas_mgr_setup_script = "cas-mgr-setup.py"
  provisioning_script = "cas-mgr-provisioning.sh"
}

resource "google_storage_bucket_object" "cas-mgr-post-install-script" {
  bucket = var.bucket_name
  name   = local.cas_mgr_setup_script
  source = "${path.module}/${local.cas_mgr_setup_script}"
}

resource "google_storage_bucket_object" "cas-mgr-provisioning-script" {
  bucket  = var.bucket_name
  name    = local.provisioning_script
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      bucket_name                = var.bucket_name,
      cas_mgr_deployment_sa_file = var.cas_mgr_deployment_sa_file,
      cas_mgr_admin_password     = var.cas_mgr_admin_password,
      cas_mgr_setup_script       = local.cas_mgr_setup_script,
      gcp_sa_file                = var.gcp_sa_file,
      kms_cryptokey_id           = var.kms_cryptokey_id,
      pcoip_registration_code    = var.pcoip_registration_code,
      teradici_download_token    = var.teradici_download_token,
    }
  )
}

resource "google_compute_instance" "cas-mgr" {
  name         = "${local.prefix}${var.host_name}"
  zone         = var.gcp_zone
  machine_type = var.machine_type

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.disk_image
      type  = "pd-standard"
      size  = var.disk_size_gb
    }
  }

  network_interface {
    subnetwork = var.subnet

    dynamic access_config {
      for_each = local.enable_public_ip
      content {}
    }
  }

  tags = var.network_tags

  metadata = {
    ssh-keys = "${var.cas_mgr_admin_user}:${file(var.cas_mgr_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.cas-mgr-provisioning-script.output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}
