/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  cam_script             = "cac-cam.py"
  cam_deployment_sa_file = "cam-cred.json"
  
  num_regions = length(var.gcp_region_list)
  num_cacs    = length(flatten(
    [ for i in range(local.num_regions):
      range(var.instance_count_list[i])
    ]
  ))

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

module "cac-regional" {
  source = "../../../modules/gcp/cac-regional"

  count = local.num_regions

  prefix = var.prefix

  gcp_region     = var.gcp_region_list[count.index]
  instance_count = var.instance_count_list[count.index]

  bucket_name = var.bucket_name

  kms_cryptokey_id            = var.kms_cryptokey_id
  cam_url                     = var.cam_url
  cac_installer_url           = var.cac_installer_url
  cam_deployment_sa_file      = local.cam_deployment_sa_file
  cam_script                  = local.cam_script
  pcoip_registration_code     = var.pcoip_registration_code

  domain_controller_ip        = var.domain_controller_ip
  domain_name                 = var.domain_name
  domain_group                = var.domain_group
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  ssl_key_filename     = local.ssl_key_filename
  ssl_cert_filename    = local.ssl_cert_filename

  network_tags = var.network_tags
  subnet = var.subnet_list[count.index]
  external_pcoip_ip = var.external_pcoip_ip_list == [] ? "" : var.external_pcoip_ip_list[count.index]

  cac_admin_user = var.cac_admin_user
  cac_admin_ssh_pub_key_file = var.cac_admin_ssh_pub_key_file

  gcp_service_account = var.gcp_service_account

  depends_on = [
    google_storage_bucket_object.ssl-key,
    google_storage_bucket_object.ssl-cert,
    google_storage_bucket_object.cam-deployment-sa-file,
    google_storage_bucket_object.cac-cam-script,
  ]
}
