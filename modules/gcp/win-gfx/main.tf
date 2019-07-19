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

  startup_script = "win-gfx-startup.ps1"
}

resource "google_storage_bucket_object" "win-gfx-startup-script" {
  name    = local.startup_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.startup_script}.tmpl",
    {
      pcoip_agent_location     = var.pcoip_agent_location,
      pcoip_agent_filename     = var.pcoip_agent_filename,
      pcoip_registration_code  = var.pcoip_registration_code,

      nvidia_driver_location   = var.nvidia_driver_location,
      nvidia_driver_filename   = var.nvidia_driver_filename,

      domain_name              = var.domain_name,
      admin_password           = var.admin_password,
      service_account_username = var.service_account_username,
      service_account_password = var.service_account_password,
    }
  )
}

resource "google_compute_instance" "win-gfx" {
  count = var.instance_count

  provider     = google
  name         = "${local.host_name}-${count.index}"
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
      #image = "projects/${var.disk_image_project}/global/images/family/${var.disk_image_family}"
      image = "projects/${var.disk_image_project}/global/images/${var.disk_image}"
      type  = "pd-ssd"
      size  = var.disk_size_gb
    }
  }

  network_interface {
    subnetwork = var.subnet
    access_config {
    }
  }

  tags = [
    "${local.prefix}tag-rdp",
    "${local.prefix}tag-icmp",
  ]

  metadata = {
    windows-startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.win-gfx-startup-script.output_name}"
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}
