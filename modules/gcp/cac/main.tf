/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  provisioning_script    = "cac-provisioning.sh"
  cam_script             = "cac-cam.py"
  cam_deployment_sa_file = "cam-cred.json"
  
  num_regions        = length(var.gcp_region_list)
  num_cacs           = length(local.instance_info_list)
  instance_info_list = flatten(
    [ for i in range(local.num_regions):
      [ for j in range(var.instance_count_list[i]):
        {
          zone   = random_shuffle.zone[i].result[j]
          subnet = var.subnet_list[i],
        }
      ]
    ]
  )

  ssl_key_filename  = var.ssl_key  == "" ? "" : basename(var.ssl_key)
  ssl_cert_filename = var.ssl_cert == "" ? "" : basename(var.ssl_cert)
}

resource "google_storage_bucket_object" "cam-deployment-sa-file" {
  count = local.num_cacs == 0 ? 0 : 1

  bucket  = var.bucket_name
  name    = local.cam_deployment_sa_file
  source  = var.cam_deployment_sa_file
}

resource "google_storage_bucket_object" "cac-cam-script" {
  count = local.num_cacs == 0 ? 0 : 1

  bucket  = var.bucket_name
  name   = local.cam_script
  source = "${path.module}/${local.cam_script}"
}

resource "google_storage_bucket_object" "ssl-key" {
  count = local.num_cacs == 0 ? 0 : var.ssl_key == "" ? 0 : 1

  bucket = var.bucket_name
  name   = local.ssl_key_filename
  source = var.ssl_key
}

resource "google_storage_bucket_object" "ssl-cert" {
  count = local.num_cacs == 0 ? 0 : var.ssl_cert == "" ? 0 : 1

  bucket = var.bucket_name
  name   = local.ssl_cert_filename
  source = var.ssl_cert
}

resource "google_storage_bucket_object" "cac-provisioning-script" {
  count = local.num_cacs == 0 ? 0 : 1

  bucket  = var.bucket_name
  name    = local.provisioning_script
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      kms_cryptokey_id            = var.kms_cryptokey_id,
      cam_url                     = var.cam_url,
      cac_installer_url           = var.cac_installer_url,
      cam_deployment_sa_file      = local.cam_deployment_sa_file,
      cam_script                  = local.cam_script,
      pcoip_registration_code     = var.pcoip_registration_code,

      domain_controller_ip        = var.domain_controller_ip,
      domain_name                 = var.domain_name,
      domain_group                = var.domain_group,
      ad_service_account_username = var.ad_service_account_username,
      ad_service_account_password = var.ad_service_account_password,

      bucket_name = var.bucket_name,
      ssl_key     = local.ssl_key_filename,
      ssl_cert    = local.ssl_cert_filename,
    }
  )
}

data "google_compute_zones" "available" {
  count  = local.num_regions

  region = var.gcp_region_list[count.index]
  status = "UP"
}

resource "random_shuffle" "zone" {
  count = local.num_regions

  input        = data.google_compute_zones.available[count.index].names
  result_count = var.instance_count_list[count.index]
}

resource "google_compute_instance" "cac" {
  count = local.num_cacs

  depends_on = [
    google_storage_bucket_object.ssl-key,
    google_storage_bucket_object.ssl-cert,
    google_storage_bucket_object.cam-deployment-sa-file,
    google_storage_bucket_object.cac-cam-script,
    # Provisioning script dependency should be inferred by Terraform
    # google_storage_bucket_object.cac-provisioning-script,
  ]

  provider     = google
  name         = "${local.prefix}${var.host_name}-${count.index}"
  zone         = local.instance_info_list[count.index].zone
  machine_type = var.machine_type

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.disk_image
      type  = "pd-ssd"
      size  = var.disk_size_gb
    }
  }

  network_interface {
    subnetwork = local.instance_info_list[count.index].subnet
    access_config {
    }
  }

  tags = var.network_tags

  metadata = {
    ssh-keys = "${var.cac_admin_user}:${file(var.cac_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.cac-provisioning-script[0].output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}
