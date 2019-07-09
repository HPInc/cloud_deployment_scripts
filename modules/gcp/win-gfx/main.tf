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
  setup_file = "C:/Temp/setup.ps1"
}

data "template_file" "sysprep-script" {
  template = file("${path.module}/sysprep.ps1.tpl")

  vars = {
    admin_password = var.admin_password
  }
}

data "template_file" "setup-script" {
  template = file("${path.module}/setup.ps1.tpl")

  vars = {
    nvidia_driver_location   = var.nvidia_driver_location
    nvidia_driver_filename   = var.nvidia_driver_filename
    pcoip_agent_location     = var.pcoip_agent_location
    pcoip_agent_filename     = var.pcoip_agent_filename
    pcoip_registration_code  = var.pcoip_registration_code
    gcp_project_id           = var.gcp_project_id
    domain_name              = var.domain_name
    domain_controller_ip     = var.domain_controller_ip
    service_account_username = var.service_account_username
    service_account_password = var.service_account_password
  }
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
    "${local.prefix}tag-winrm",
    "${local.prefix}tag-icmp",
  ]

  metadata = {
    sysprep-specialize-script-ps1 = data.template_file.sysprep-script.rendered
  }
}

resource "null_resource" "upload-scripts" {
  count = var.instance_count

  depends_on = [google_compute_instance.win-gfx]
  triggers = {
    instance_id = google_compute_instance.win-gfx[count.index].instance_id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = var.admin_password
    host     = google_compute_instance.win-gfx[count.index].network_interface[0].access_config[0].nat_ip
    port     = "5986"
    https    = true
    insecure = true
  }

  provisioner "file" {
    content     = data.template_file.setup-script.rendered
    destination = local.setup_file
  }
}

resource "null_resource" "run-setup-script" {
  count = var.instance_count

  depends_on = [null_resource.upload-scripts]
  triggers = {
    instance_id = google_compute_instance.win-gfx[count.index].instance_id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"
    password = var.admin_password
    host     = google_compute_instance.win-gfx[count.index].network_interface[0].access_config[0].nat_ip
    port     = "5986"
    https    = true
    insecure = true
  }

  provisioner "remote-exec" {
    inline = ["powershell -file ${local.setup_file}"]
  }
}
