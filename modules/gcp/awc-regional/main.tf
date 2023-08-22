/*
 * © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  enable_public_ip    = (var.enable_awc_external_ip || var.external_pcoip_ip == "") ? [true] : []
  prefix              = var.prefix != "" ? "${var.prefix}-" : ""
  provisioning_script = "awc-provisioning.sh"
}

resource "google_storage_bucket_object" "awc-provisioning-script" {
  count = var.instance_count == 0 ? 0 : 1

  bucket = var.bucket_name
  name   = "${local.provisioning_script}-${var.gcp_region}"
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      ad_service_account_password = var.ad_service_account_password,
      ad_service_account_username = var.ad_service_account_username,
      awc_extra_install_flags     = var.awc_extra_install_flags,
      awc_flag_manager_insecure   = var.awc_flag_manager_insecure,
      bucket_name                 = var.bucket_name,
      computers_dn                = var.computers_dn,
      awm_deployment_sa_file      = var.awm_deployment_sa_file,
      awm_script                  = var.awm_script,
      bucket_name                 = var.bucket_name,
      domain_controller_ip        = var.domain_controller_ip,
      domain_name                 = var.domain_name,
      external_pcoip_ip           = var.external_pcoip_ip,
      gcp_ops_agent_enable        = var.gcp_ops_agent_enable,
      ldaps_cert_filename         = var.ldaps_cert_filename,
      manager_url                 = var.manager_url,
      ops_setup_script            = var.ops_setup_script,
      tls_cert                    = var.tls_cert_filename,
      tls_key                     = var.tls_key_filename,
      teradici_download_token     = var.teradici_download_token,
      users_dn                    = var.users_dn
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

resource "google_compute_instance" "awc" {
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

    dynamic "access_config" {
      for_each = local.enable_public_ip
      content {}
    }
  }

  tags = var.network_tags

  metadata = {
    ssh-keys           = "${var.awc_admin_user}:${file(var.awc_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.awc-provisioning-script[0].output_name}"
  }

  service_account {
    email  = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}
