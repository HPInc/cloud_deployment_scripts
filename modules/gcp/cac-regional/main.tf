/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  enable_public_ip    = var.external_pcoip_ip == "" ? [true] : []
  prefix              = var.prefix != "" ? "${var.prefix}-" : ""
  provisioning_script = "cac-provisioning.sh"
}

resource "google_storage_bucket_object" "cac-provisioning-script" {
  count = var.instance_count

  bucket  = var.bucket_name
  name    = "${local.provisioning_script}-${var.gcp_region}"
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      ad_service_account_password = var.ad_service_account_password,
      ad_service_account_username = var.ad_service_account_username,
      bucket_name                 = var.bucket_name,
      cac_version                 = var.cac_version,
      cas_mgr_deployment_sa_file  = var.cas_mgr_deployment_sa_file,
      cas_mgr_insecure            = var.cas_mgr_insecure ? "true" : "", 
      cas_mgr_script              = var.cas_mgr_script,
      cas_mgr_url                 = var.cas_mgr_url,
      domain_controller_ip        = var.domain_controller_ip,
      domain_group                = var.domain_group,
      domain_name                 = var.domain_name,
      external_pcoip_ip           = var.external_pcoip_ip,
      kms_cryptokey_id            = var.kms_cryptokey_id,
      pcoip_registration_code     = var.pcoip_registration_code,
      ssl_cert                    = var.ssl_cert_filename,
      ssl_key                     = var.ssl_key_filename,
      teradici_download_token     = var.teradici_download_token,
    }
  )
}

data "google_compute_zones" "available" {
  region = var.gcp_region
  status = "UP"
}

resource "random_shuffle" "zone" {
  input        = data.google_compute_zones.available.names
  result_count = var.instance_count
}

resource "google_compute_instance" "cac" {
  count = var.instance_count

  name         = "${local.prefix}${var.host_name}-${var.gcp_region}-${count.index}"
  zone         = random_shuffle.zone.result[count.index]
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

    dynamic access_config {
      for_each = local.enable_public_ip
      content {}
    }
  }

  tags = var.network_tags

  metadata = {
    ssh-keys = "${var.cac_admin_user}:${file(var.cac_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.cac-provisioning-script[0].output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}
