/*
 * © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  provisioning_script = "awc-provisioning.sh"
  awm_script          = "get-connector-token.py"

  num_instances = length(flatten([for i in var.instance_count_list : range(i)]))
  num_regions   = length(var.gcp_region_list)

  enable_public_ip = var.external_pcoip_ip == "" ? [true] : []

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

resource "google_storage_bucket_object" "get-awc-token-script" {
  count = local.num_instances == 0 ? 0 : 1

  bucket = var.bucket_name
  name   = local.awm_script
  source = "${path.module}/${local.awm_script}"
}

# This is needed so new VMs will be based on the same image in case the public
# images gets updated
data "google_compute_image" "awc-base-img" {
  project = local.disk_image_project
  family  = local.disk_image_family
  name    = local.disk_image_name
}

resource "google_storage_bucket_object" "awc-provisioning-script" {
  count = local.num_instances == 0 ? 0 : 1

  bucket = var.bucket_name
  name   = local.provisioning_script
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      ad_service_account_password_id = var.ad_service_account_password_id,
      ad_service_account_username    = var.ad_service_account_username,
      awc_extra_install_flags        = var.awc_extra_install_flags,
      awc_flag_manager_insecure      = var.awc_flag_manager_insecure,
      awm_deployment_sa_file         = var.awm_deployment_sa_file,
      awm_deployment_sa_file_id      = var.awm_deployment_sa_file_id,
      awm_script                     = local.awm_script,
      bucket_name                    = var.bucket_name,
      computers_dn                   = var.computers_dn,
      domain_controller_ip           = var.domain_controller_ip,
      domain_name                    = var.domain_name,
      external_pcoip_ip              = var.external_pcoip_ip,
      gcp_ops_agent_enable           = var.gcp_ops_agent_enable,
      ldaps_cert_filename            = var.ldaps_cert_filename,
      manager_url                    = var.manager_url,
      ops_setup_script               = var.ops_setup_script,
      tls_cert                       = var.tls_cert,
      tls_key                        = var.tls_key,
      teradici_download_token        = var.teradici_download_token,
      users_dn                       = var.users_dn,
    }
  )
}

# One template per region because of the different subnets
resource "google_compute_instance_template" "awc-template" {
  count = local.num_regions

  depends_on = [
    google_storage_bucket_object.get-awc-token-script,
    # Provisioning script dependency should be inferred by Terraform
    # google_storage_bucket_object.awc-provisioning-script,
  ]

  name_prefix = "${local.prefix}template-awc-${var.gcp_region_list[count.index]}"

  machine_type = var.machine_type

  disk {
    boot         = true
    source_image = data.google_compute_image.awc-base-img.self_link
    disk_type    = "pd-ssd"
    disk_size_gb = var.disk_size_gb
  }

  network_interface {
    subnetwork = var.subnet_list[count.index]

    dynamic "access_config" {
      for_each = local.enable_public_ip
      content {}
    }
  }

  tags = var.network_tags

  lifecycle {
    create_before_destroy = true
  }

  metadata = {
    ssh-keys           = "${var.awc_admin_user}:${file(var.awc_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.awc-provisioning-script[0].output_name}"
  }

  service_account {
    email  = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_region_instance_group_manager" "awc-igm" {
  count = local.num_regions

  name   = "${local.prefix}igm-awc-${var.gcp_region_list[count.index]}"
  region = var.gcp_region_list[count.index]

  base_instance_name = "${local.prefix}${var.host_name}-${var.gcp_region_list[count.index]}"

  version {
    instance_template = google_compute_instance_template.awc-template[count.index].self_link
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
