/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  # Convert bool to iterable collection so it can be used with for_each
  enable_public_ip = var.enable_public_ip ? [true] : []
  cam_setup_script = "cam-setup.py"
  provisioning_script = "cam-provisioning.sh"
}

resource "google_storage_bucket_object" "cam-post-install-script" {
  bucket = var.bucket_name
  name   = local.cam_setup_script
  source = "${path.module}/${local.cam_setup_script}"
}

resource "google_storage_bucket_object" "cam-provisioning-script" {
  bucket  = var.bucket_name
  name    = local.provisioning_script
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      bucket_name             = var.bucket_name,
      cam_add_repo_script     = var.cam_add_repo_script,
      cam_deployment_sa_file  = var.cam_deployment_sa_file,
      cam_gui_admin_password  = var.cam_gui_admin_password,
      cam_setup_script        = local.cam_setup_script,
      gcp_sa_file             = var.gcp_sa_file,
      kms_cryptokey_id        = var.kms_cryptokey_id,
      pcoip_registration_code = var.pcoip_registration_code,
    }
  )
}

resource "google_compute_instance" "cam" {
  name         = "${local.prefix}${var.host_name}"
  zone         = var.gcp_zone
  machine_type = var.machine_type

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.disk_image
      type  = "pd-standard"
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
    ssh-keys = "${var.cam_admin_user}:${file(var.cam_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.cam-provisioning-script.output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}
