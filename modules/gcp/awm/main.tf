/*
 * Copyright (c) 2020 Teradici Corporation; © Copyright 2023-2024 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  # Convert bool to iterable collection so it can be used with for_each
  enable_public_ip    = var.enable_public_ip ? [true] : []
  awm_setup_script    = "awm-setup.py"
  provisioning_script = "awm-provisioning.sh"
}

resource "google_storage_bucket_object" "awm-post-install-script" {
  bucket = var.bucket_name
  name   = local.awm_setup_script
  source = "${path.module}/${local.awm_setup_script}"
}

resource "google_storage_bucket_object" "awm-provisioning-script" {
  bucket = var.bucket_name
  name   = local.provisioning_script
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      awm_deployment_sa_file     = var.awm_deployment_sa_file,
      awm_deployment_sa_file_id  = var.awm_deployment_sa_file_id,
      awm_admin_password_id      = var.awm_admin_password_id,
      awm_repo_channel           = var.awm_repo_channel,
      awm_setup_script           = local.awm_setup_script,
      bucket_name                = var.bucket_name,
      gcp_ops_agent_enable       = var.gcp_ops_agent_enable,
      gcp_sa_file                = var.gcp_sa_file,
      gcp_sa_file_id             = var.gcp_sa_file_id,
      ops_setup_script           = var.ops_setup_script,
      pcoip_registration_code_id = var.pcoip_registration_code_id,
      teradici_download_token    = var.teradici_download_token,
    }
  )
}

resource "google_compute_instance" "awm" {
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

    dynamic "access_config" {
      for_each = local.enable_public_ip
      content {}
    }
  }

  tags = var.network_tags

  metadata = {
    ssh-keys           = "${var.awm_admin_user}:${file(var.awm_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.awm-provisioning-script.output_name}"
  }

  service_account {
    email  = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}
