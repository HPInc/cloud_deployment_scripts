/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  bucket_name = "${local.prefix}pcoip-scripts-${random_id.bucket-name.hex}"
  # Name of CAS Manager deployment service account key file in bucket
  cas_mgr_deployment_sa_file = "cas-mgr-deployment-sa-key.json"

  gcp_service_account = jsondecode(file(var.gcp_credentials_file))["client_email"]
  gcp_project_id = jsondecode(file(var.gcp_credentials_file))["project_id"]
}

resource "random_id" "bucket-name" {
  byte_length = 3
}

resource "google_storage_bucket" "scripts" {
  name          = local.bucket_name
  location      = var.gcp_region
  storage_class = "REGIONAL"
  force_destroy = true
}

resource "google_storage_bucket_object" "cas-mgr-deployment-sa-file" {
  bucket = google_storage_bucket.scripts.name
  name   = local.cas_mgr_deployment_sa_file
  source = var.cas_mgr_deployment_sa_file
}

module "dc" {
  source = "../../../modules/gcp/dc"

  prefix = var.prefix

  gcp_service_account         = local.gcp_service_account
  kms_cryptokey_id            = var.kms_cryptokey_id
  domain_name                 = var.domain_name
  admin_password              = var.dc_admin_password
  safe_mode_admin_password    = var.safe_mode_admin_password
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password
  domain_users_list           = var.domain_users_list

  bucket_name  = google_storage_bucket.scripts.name
  gcp_zone     = var.gcp_zone
  subnet       = google_compute_subnetwork.dc-subnet.self_link
  private_ip   = var.dc_private_ip
  network_tags = [
    google_compute_firewall.allow-google-dns.name,
    google_compute_firewall.allow-rdp.name,
    google_compute_firewall.allow-winrm.name,
    google_compute_firewall.allow-icmp.name,
  ]

  machine_type = var.dc_machine_type
  disk_size_gb = var.dc_disk_size_gb

  disk_image = var.dc_disk_image
}

module "cac" {
  source = "../../../modules/gcp/cac"

  prefix = var.prefix

  gcp_service_account     = local.gcp_service_account
  kms_cryptokey_id        = var.kms_cryptokey_id
  cas_mgr_url             = var.cas_mgr_url
  pcoip_registration_code = var.pcoip_registration_code
  
  domain_name                 = var.domain_name
  domain_controller_ip        = module.dc.internal-ip
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name                = google_storage_bucket.scripts.name
  cas_mgr_deployment_sa_file = local.cas_mgr_deployment_sa_file

  gcp_region_list = [var.gcp_region]
  subnet_list     = [google_compute_subnetwork.cac-subnet.self_link]
  network_tags    = [
    google_compute_firewall.allow-ssh.name,
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-pcoip.name,
  ]

  instance_count_list = [var.cac_instance_count]
  machine_type        = var.cac_machine_type
  disk_size_gb        = var.cac_disk_size_gb

  disk_image = var.cac_disk_image

  cac_admin_user              = var.cac_admin_user
  cac_admin_ssh_pub_key_file  = var.cac_admin_ssh_pub_key_file

  ssl_key  = var.cac_ssl_key
  ssl_cert = var.cac_ssl_cert
}

module "win-gfx" {
  source = "../../../modules/gcp/win-gfx"

  prefix = var.prefix

  gcp_service_account = local.gcp_service_account
  kms_cryptokey_id    = var.kms_cryptokey_id

  pcoip_registration_code = var.pcoip_registration_code
  teradici_download_token = var.teradici_download_token
  pcoip_agent_version     = var.win_gfx_pcoip_agent_version

  domain_name                 = var.domain_name
  admin_password              = var.dc_admin_password
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name      = google_storage_bucket.scripts.name
  zone_list        = [var.gcp_zone]
  subnet_list      = [google_compute_subnetwork.ws-subnet.self_link]
  enable_public_ip = var.enable_workstation_public_ip

  enable_workstation_idle_shutdown = var.enable_workstation_idle_shutdown
  minutes_idle_before_shutdown     = var.minutes_idle_before_shutdown
  minutes_cpu_polling_interval     = var.minutes_cpu_polling_interval

  network_tags     = [
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-rdp.name,
  ]

  instance_count_list = [var.win_gfx_instance_count]
  instance_name       = var.win_gfx_instance_name
  machine_type        = var.win_gfx_machine_type
  accelerator_type    = var.win_gfx_accelerator_type
  accelerator_count   = var.win_gfx_accelerator_count
  disk_size_gb        = var.win_gfx_disk_size_gb
  disk_image          = var.win_gfx_disk_image

  depends_on = [google_compute_router_nat.nat]
}

module "win-std" {
  source = "../../../modules/gcp/win-std"

  prefix = var.prefix

  gcp_service_account = local.gcp_service_account
  kms_cryptokey_id    = var.kms_cryptokey_id

  pcoip_registration_code = var.pcoip_registration_code
  teradici_download_token = var.teradici_download_token
  pcoip_agent_version     = var.win_std_pcoip_agent_version

  domain_name                 = var.domain_name
  admin_password              = var.dc_admin_password
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name      = google_storage_bucket.scripts.name
  zone_list        = [var.gcp_zone]
  subnet_list      = [google_compute_subnetwork.ws-subnet.self_link]
  enable_public_ip = var.enable_workstation_public_ip

  enable_workstation_idle_shutdown = var.enable_workstation_idle_shutdown
  minutes_idle_before_shutdown     = var.minutes_idle_before_shutdown
  minutes_cpu_polling_interval     = var.minutes_cpu_polling_interval

  network_tags     = [
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-rdp.name,
  ]

  instance_count_list = [var.win_std_instance_count]
  instance_name       = var.win_std_instance_name
  machine_type        = var.win_std_machine_type
  disk_size_gb        = var.win_std_disk_size_gb
  disk_image          = var.win_std_disk_image

  depends_on = [google_compute_router_nat.nat]
}

module "centos-gfx" {
  source = "../../../modules/gcp/centos-gfx"

  prefix = var.prefix

  gcp_service_account = local.gcp_service_account
  kms_cryptokey_id    = var.kms_cryptokey_id

  pcoip_registration_code = var.pcoip_registration_code
  teradici_download_token = var.teradici_download_token

  domain_name                 = var.domain_name
  domain_controller_ip        = module.dc.internal-ip
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name      = google_storage_bucket.scripts.name
  zone_list        = [var.gcp_zone]
  subnet_list      = [google_compute_subnetwork.ws-subnet.self_link]
  enable_public_ip = var.enable_workstation_public_ip

  enable_workstation_idle_shutdown = var.enable_workstation_idle_shutdown
  minutes_idle_before_shutdown     = var.minutes_idle_before_shutdown
  minutes_cpu_polling_interval     = var.minutes_cpu_polling_interval

  network_tags     = [
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-ssh.name,
  ]

  instance_count_list = [var.centos_gfx_instance_count]
  instance_name       = var.centos_gfx_instance_name
  machine_type        = var.centos_gfx_machine_type
  accelerator_type    = var.centos_gfx_accelerator_type
  accelerator_count   = var.centos_gfx_accelerator_count
  disk_size_gb        = var.centos_gfx_disk_size_gb
  disk_image          = var.centos_gfx_disk_image

  ws_admin_user              = var.centos_admin_user
  ws_admin_ssh_pub_key_file  = var.centos_admin_ssh_pub_key_file

  depends_on = [google_compute_router_nat.nat]
}

module "centos-std" {
  source = "../../../modules/gcp/centos-std"

  prefix = var.prefix

  gcp_service_account = local.gcp_service_account
  kms_cryptokey_id    = var.kms_cryptokey_id

  pcoip_registration_code = var.pcoip_registration_code
  teradici_download_token = var.teradici_download_token

  domain_name                 = var.domain_name
  domain_controller_ip        = module.dc.internal-ip
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name      = google_storage_bucket.scripts.name
  zone_list        = [var.gcp_zone]
  subnet_list      = [google_compute_subnetwork.ws-subnet.self_link]
  enable_public_ip = var.enable_workstation_public_ip

  enable_workstation_idle_shutdown = var.enable_workstation_idle_shutdown
  minutes_idle_before_shutdown     = var.minutes_idle_before_shutdown
  minutes_cpu_polling_interval     = var.minutes_cpu_polling_interval

  network_tags     = [
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-ssh.name,
  ]

  instance_count_list = [var.centos_std_instance_count]
  instance_name       = var.centos_std_instance_name
  machine_type        = var.centos_std_machine_type
  disk_size_gb        = var.centos_std_disk_size_gb
  disk_image          = var.centos_std_disk_image

  ws_admin_user              = var.centos_admin_user
  ws_admin_ssh_pub_key_file  = var.centos_admin_ssh_pub_key_file

  depends_on = [google_compute_router_nat.nat]
}
