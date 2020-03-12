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
  host_name = substr("${local.prefix}${var.name}", 0, 11)

  enable_public_ip = var.enable_public_ip ? [true] : []
  startup_script = "centos-gfx-startup.sh"
}

resource "google_storage_bucket_object" "centos-gfx-startup-script" {
  count = tonumber(var.instance_count) == 0 ? 0 : 1

  name    = local.startup_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.startup_script}.tmpl",
    {
      kms_cryptokey_id            = var.kms_cryptokey_id,
      pcoip_registration_code     = var.pcoip_registration_code,
      domain_controller_ip        = var.domain_controller_ip,
      domain_name                 = var.domain_name,
      ad_service_account_username = var.ad_service_account_username,
      ad_service_account_password = var.ad_service_account_password,
      nvidia_driver_url           = var.nvidia_driver_url,
      pcoip_agent_repo_pubkey_url = var.pcoip_agent_repo_pubkey_url,
      pcoip_agent_repo_url        = var.pcoip_agent_repo_url,

      enable_workstation_idle_shutdown = var.enable_workstation_idle_shutdown,
      minutes_idle_before_shutdown     = var.minutes_idle_before_shutdown,
      minutes_cpu_polling_interval     = var.minutes_cpu_polling_interval,
    }
  )
}

resource "google_compute_instance" "centos-gfx" {
  count = var.instance_count

  provider     = google
  name         = "${local.host_name}-${count.index}"
  zone         = var.gcp_zone
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
    subnetwork = var.subnet

    dynamic access_config {
      for_each = local.enable_public_ip
      content {}
    }
  }

  tags = var.network_tags

  metadata = {
    ssh-keys = "${var.ws_admin_user}:${file(var.ws_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.centos-gfx-startup-script[0].output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}
