/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  # Windows computer names must be <= 15 characters, minus 4 chars for "-xyz"
  # where xyz is number of instances (0-999)
  host_name = substr("${local.prefix}${var.instance_name}", 0, 11)
  instance_info_list = flatten(
    [ for i in range(length(var.zone_list)):
      [ for j in range(var.instance_count_list[i]):
        {
          zone   = var.zone_list[i],
          subnet = var.subnet_list[i],
        }
      ]
    ]
  )
  enable_public_ip = var.enable_public_ip ? [true] : []
  provisioning_script = "centos-gfx-provisioning.sh"
}

resource "google_storage_bucket_object" "centos-gfx-provisioning-script" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  name    = local.provisioning_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      ad_service_account_password = var.ad_service_account_password,
      ad_service_account_username = var.ad_service_account_username,
      bucket_name                 = var.bucket_name, 
      domain_controller_ip        = var.domain_controller_ip,
      domain_name                 = var.domain_name,
      kms_cryptokey_id            = var.kms_cryptokey_id,
      nvidia_driver_url           = var.nvidia_driver_url,
      ops_setup_script            = var.ops_setup_script,
      pcoip_registration_code     = var.pcoip_registration_code,
      teradici_download_token     = var.teradici_download_token,

      idle_shutdown_enable                       = var.idle_shutdown_enable,
      idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown,
      idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes,
    }
  )
}

resource "google_compute_instance" "centos-gfx" {
  count = length(local.instance_info_list)

  provider     = google
  name         = "${local.host_name}-${count.index}"
  zone         = local.instance_info_list[count.index].zone
  machine_type = var.machine_type

  guest_accelerator {
    type  = var.accelerator_type
    count = var.accelerator_count
  }

  # This is needed to prevent "Instances with guest accelerators do not support live migration" error
  scheduling {
    on_host_maintenance = "TERMINATE"
  }

  boot_disk {
    initialize_params {
      image = var.disk_image
      type  = "pd-ssd"
      size  = var.disk_size_gb
    }
  }

  network_interface {
    subnetwork = local.instance_info_list[count.index].subnet

    dynamic access_config {
      for_each = local.enable_public_ip
      content {}
    }
  }

  tags = var.network_tags

  metadata = {
    ssh-keys = "${var.ws_admin_user}:${file(var.ws_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.centos-gfx-provisioning-script[0].output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}
