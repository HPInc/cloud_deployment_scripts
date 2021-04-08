/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  provisioning_script = "cac-provisioning.sh"
  cas_mgr_script      = "get-cac-token.py"

  num_cacs    = length(flatten([for i in var.instance_count_list: range(i)]))
  num_regions = length(var.gcp_region_list)

  enable_public_ip    = var.external_pcoip_ip == "" ? [true] : []

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

resource "google_storage_bucket_object" "get-cac-token-script" {
  count = local.num_cacs == 0 ? 0 : 1

  bucket = var.bucket_name
  name   = local.cas_mgr_script
  source = "${path.module}/${local.cas_mgr_script}"
}

# This is needed so new VMs will be based on the same image in case the public
# images gets updated
data "google_compute_image" "cac-base-img" {
  project = local.disk_image_project
  family  = local.disk_image_family
  name    = local.disk_image_name
}

resource "google_storage_bucket_object" "cac-provisioning-script" {
  count = local.num_cacs == 0 ? 0 : 1

  bucket  = var.bucket_name
  name    = local.provisioning_script
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      ad_service_account_password = var.ad_service_account_password,
      ad_service_account_username = var.ad_service_account_username,
      bucket_name                 = var.bucket_name,
      cac_extra_install_flags     = var.cac_extra_install_flags,
      cac_version                 = var.cac_version,
      cas_mgr_deployment_sa_file  = var.cas_mgr_deployment_sa_file,
      cas_mgr_insecure            = var.cas_mgr_insecure ? "true" : "",
      cas_mgr_script              = local.cas_mgr_script,
      cas_mgr_url                 = var.cas_mgr_url,
      domain_controller_ip        = var.domain_controller_ip,
      domain_name                 = var.domain_name,
      external_pcoip_ip           = var.external_pcoip_ip,
      kms_cryptokey_id            = var.kms_cryptokey_id,
      pcoip_registration_code     = var.pcoip_registration_code,
      ssl_cert                    = var.ssl_cert,
      ssl_key                     = var.ssl_key,
      teradici_download_token     = var.teradici_download_token,
    }
  )
}

# One template per region because of the different subnets
resource "google_compute_instance_template" "cac-template" {
  count = local.num_regions

  depends_on = [
    google_storage_bucket_object.get-cac-token-script,
    # Provisioning script dependency should be inferred by Terraform
    # google_storage_bucket_object.cac-provisioning-script,
  ]

  name_prefix = "${local.prefix}template-cac-${var.gcp_region_list[count.index]}"

  machine_type = var.machine_type

  disk {
    boot         = true
    source_image = data.google_compute_image.cac-base-img.self_link
    disk_type    = "pd-ssd"
    disk_size_gb = var.disk_size_gb
  }

  network_interface {
    subnetwork = var.subnet_list[count.index]

    dynamic access_config {
      for_each = local.enable_public_ip
      content {}
    }
  }

  tags = var.network_tags

  lifecycle {
    create_before_destroy = true
  }

  metadata = {
    ssh-keys = "${var.cac_admin_user}:${file(var.cac_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.cac-provisioning-script[0].output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_region_instance_group_manager" "cac-igm" {
  count = local.num_regions

  name   = "${local.prefix}igm-cac-${var.gcp_region_list[count.index]}"
  region = var.gcp_region_list[count.index]

  base_instance_name = "${local.prefix}${var.host_name}-${var.gcp_region_list[count.index]}"

  version {
    instance_template = google_compute_instance_template.cac-template[count.index].self_link
  }

  named_port {
    name = "https"
    port = 443
  }

  # Used by both TCP and UDP backend services
  named_port {
    name = "pcoip"
    port = 4172
  }

  # Overridden by autoscaler when autoscaler is enabled
  target_size = var.instance_count_list[count.index]
}
