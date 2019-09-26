/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  startup_script = "cac-startup.sh"
  num_cacs = length(flatten([for i in var.instance_count_list: range(i)]))
  num_regions = length(var.gcp_zone_list)

  disk_image_project = regex("^projects/([-\\w]+).+$", var.disk_image)[0]
  disk_image_family = length(
      regexall(
        "^projects/${local.disk_image_project}/global/images/family/([-\\w]+)$",
        var.disk_image
      )
    ) > 0 ? regex(
        "^projects/${local.disk_image_project}/global/images/family/([-\\w]+)$",
        var.disk_image
      )[0] : null
  disk_image_name = local.disk_image_family == null ? regex(
      "^projects/${local.disk_image_project}/global/images/([-\\w]+)$",
      var.disk_image
    )[0] : null
}

# This is needed so new VMs will be based on the same image in case the public
# images gets updated
data "google_compute_image" "cac-base-img" {
  project = local.disk_image_project
  family  = local.disk_image_family
  name    = local.disk_image_name
}

resource "google_storage_bucket_object" "cac-startup-script" {
  count = local.num_cacs == 0 ? 0 : 1

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
  count = local.num_regions

  name_prefix = "${local.prefix}template-cac-${var.gcp_zone_list[count.index]}"

  machine_type = var.machine_type

  disk {
    boot         = true
    source_image = data.google_compute_image.cac-base-img.self_link
    disk_type    = "pd-ssd"
    disk_size_gb = var.disk_size_gb
  }

  network_interface {
    subnetwork = var.subnet_list[count.index]
    access_config {
    }
  }

  tags = var.network_tags

  lifecycle {
    create_before_destroy = true
  }

  metadata = {
    ssh-keys = "${var.cac_admin_user}:${file(var.cac_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.cac-startup-script[0].output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance_group_manager" "cac-igm" {
  count = local.num_regions

  name = "${local.prefix}igm-cac"

  # TODO: makes more sense to use regional IGM
  #region = "${var.gcp_region}"
  zone = var.gcp_zone_list[count.index]

  base_instance_name = "${local.prefix}cac"
  instance_template = google_compute_instance_template.cac-template[count.index].self_link

  named_port {
    name = "https"
    port = 443
  }

  # Overridden by autoscaler when autoscaler is enabled
  target_size = var.instance_count_list[count.index]
}
