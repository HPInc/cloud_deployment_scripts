/*
 * © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  awm_script = "get-connector-token.py"

  num_regions = length(var.gcp_region_list)
  num_instances = length(flatten(
    [for i in range(local.num_regions) :
      range(var.instance_count_list[i])
    ]
  ))

  tls_key_filename  = var.tls_key == "" ? "" : basename(var.tls_key)
  tls_cert_filename = var.tls_cert == "" ? "" : basename(var.tls_cert)
}

resource "google_storage_bucket_object" "get-connector-token-script" {
  count = local.num_instances == 0 ? 0 : 1

  bucket = var.bucket_name
  name   = local.awm_script
  source = "${path.module}/${local.awm_script}"
}

resource "google_storage_bucket_object" "tls-key" {
  count = local.num_instances == 0 ? 0 : var.tls_key == "" ? 0 : 1

  bucket = var.bucket_name
  name   = local.tls_key_filename
  source = var.tls_key
}

resource "google_storage_bucket_object" "tls-cert" {
  count = local.num_instances == 0 ? 0 : var.tls_cert == "" ? 0 : 1

  bucket = var.bucket_name
  name   = local.tls_cert_filename
  source = var.tls_cert
}

module "awc-regional" {
  source = "../../../modules/gcp/awc-regional"

  count = local.num_regions

  prefix = var.prefix

  gcp_region     = var.gcp_region_list[count.index]
  instance_count = var.instance_count_list[count.index]

  bucket_name            = var.bucket_name
  awm_deployment_sa_file = var.awm_deployment_sa_file

  awm_script                = local.awm_script
  awc_flag_manager_insecure = var.awc_flag_manager_insecure
  manager_url               = var.manager_url

  domain_controller_ip        = var.domain_controller_ip
  domain_name                 = var.domain_name
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password
  ldaps_cert_filename         = var.ldaps_cert_filename
  computers_dn                = var.computers_dn
  users_dn                    = var.users_dn

  tls_key_filename  = local.tls_key_filename
  tls_cert_filename = local.tls_cert_filename

  awc_extra_install_flags = var.awc_extra_install_flags

  network_tags           = var.network_tags
  subnet                 = var.subnet_list[count.index]
  external_pcoip_ip      = var.external_pcoip_ip_list == [] ? "" : var.external_pcoip_ip_list[count.index]
  enable_awc_external_ip = var.enable_awc_external_ip

  awc_admin_user             = var.awc_admin_user
  awc_admin_ssh_pub_key_file = var.awc_admin_ssh_pub_key_file
  teradici_download_token    = var.teradici_download_token

  gcp_service_account = var.gcp_service_account

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = var.ops_setup_script

  depends_on = [
    google_storage_bucket_object.tls-key,
    google_storage_bucket_object.tls-cert,
    google_storage_bucket_object.get-connector-token-script,
  ]
}
