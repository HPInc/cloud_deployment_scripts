/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
}

module "dc" {
  source = "../../../modules/gcp/dc"

  prefix = var.prefix

  domain_name              = var.domain_name
  admin_password           = var.dc_admin_password
  safe_mode_admin_password = var.safe_mode_admin_password
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password
  domain_users_list        = var.domain_users_list

  subnet     = google_compute_subnetwork.dc-subnet.self_link
  private_ip = var.dc_private_ip

  machine_type       = var.dc_machine_type
  disk_size_gb       = var.dc_disk_size_gb
}

module "cac" {
  source = "../../../modules/gcp/cac"

  prefix = var.prefix

  cam_url                 = var.cam_url
  pcoip_registration_code = var.pcoip_registration_code
  cac_token               = var.cac_token

  domain_name              = var.domain_name
  domain_controller_ip     = module.dc.internal-ip
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  gcp_zone       = var.gcp_zone
  subnet         = google_compute_subnetwork.cac-subnet.self_link
  instance_count = var.cac_instance_count

  machine_type       = var.cac_machine_type
  disk_image_project = var.cac_disk_image_project
  disk_image_family  = var.cac_disk_image_family
  disk_size_gb       = var.cac_disk_size_gb

  cac_admin_user              = var.cac_admin_user
  cac_admin_ssh_pub_key_file  = var.cac_admin_ssh_pub_key_file
  cac_admin_ssh_priv_key_file = var.cac_admin_ssh_priv_key_file

  ssl_key  = var.ssl_key
  ssl_cert = var.ssl_cert
}

module "win-gfx" {
  source = "../../../modules/gcp/win-gfx"

  prefix = var.prefix

  pcoip_registration_code = var.pcoip_registration_code

  domain_name              = var.domain_name
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  gcp_project_id = var.gcp_project_id
  subnet         = google_compute_subnetwork.ws-subnet.self_link
  instance_count = var.win_gfx_instance_count

  machine_type      = var.win_gfx_machine_type
  accelerator_type  = var.win_gfx_accelerator_type
  accelerator_count = var.win_gfx_accelerator_count
  disk_size_gb      = var.win_gfx_disk_size_gb

  admin_password = var.dc_admin_password
}

module "centos-gfx" {
  source = "../../../modules/gcp/centos-gfx"

  prefix = var.prefix

  pcoip_registration_code = var.pcoip_registration_code

  domain_name              = var.domain_name
  domain_controller_ip     = module.dc.internal-ip
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  subnet         = google_compute_subnetwork.ws-subnet.self_link
  instance_count = var.centos_gfx_instance_count

  machine_type      = var.centos_gfx_machine_type
  accelerator_type  = var.centos_gfx_accelerator_type
  accelerator_count = var.centos_gfx_accelerator_count
  disk_size_gb      = var.centos_gfx_disk_size_gb

  ws_admin_user              = var.centos_admin_user
  ws_admin_ssh_pub_key_file  = var.centos_admin_ssh_pub_key_file
  ws_admin_ssh_priv_key_file = var.centos_admin_ssh_priv_key_file
}

module "centos-std" {
  source = "../../../modules/gcp/centos-std"

  prefix = var.prefix

  pcoip_registration_code = var.pcoip_registration_code

  domain_name              = var.domain_name
  domain_controller_ip     = module.dc.internal-ip
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  subnet         = google_compute_subnetwork.ws-subnet.self_link
  instance_count = var.centos_std_instance_count

  machine_type = var.centos_std_machine_type
  disk_size_gb = var.centos_std_disk_size_gb

  ws_admin_user              = var.centos_admin_user
  ws_admin_ssh_pub_key_file  = var.centos_admin_ssh_pub_key_file
  ws_admin_ssh_priv_key_file = var.centos_admin_ssh_priv_key_file
}
