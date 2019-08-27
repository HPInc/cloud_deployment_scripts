/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  startup_script    = "cac-startup.sh"
}

# This is needed so new VMs will be based on the same image in case the public
# images gets updated
data "google_compute_image" "cac-base-img" {
  project = var.disk_image_project
  family  = var.disk_image_family
}

resource "google_storage_bucket_object" "startup-script" {
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
      ssl_key     = "",
      ssl_cert    = "",
    }
  )
}

resource "google_compute_instance_template" "cac-template" {
  name_prefix = "${local.prefix}template-cac"

  machine_type = var.machine_type

  disk {
    boot         = true
    source_image = data.google_compute_image.cac-base-img.self_link
    disk_type    = "pd-ssd"
    disk_size_gb = var.disk_size_gb
  }

  network_interface {
    subnetwork = var.subnet
    access_config {
    }
  }

  tags = [
    "${local.prefix}tag-ssh",
    "${local.prefix}tag-icmp",
    "${local.prefix}tag-http",
    "${local.prefix}tag-https",
    "${local.prefix}tag-pcoip",
  ]

  lifecycle {
    create_before_destroy = true
  }

  metadata = {
    ssh-keys = "${var.cac_admin_user}:${file(var.cac_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.startup-script.output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance_group_manager" "cac-igm" {
  name = "${local.prefix}igm-cac"

  # TODO: makes more sense to use regional IGM
  #region = "${var.gcp_region}"
  zone = var.gcp_zone

  base_instance_name = "${local.prefix}cac"
  instance_template = google_compute_instance_template.cac-template.self_link

  named_port {
    name = "https"
    port = 443
  }

  # Overridden by autoscaler when autoscaler is enabled
  target_size = var.cac_instances
}
