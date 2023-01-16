/*
 * Copyright Teradici Corporation 2021;  © Copyright 2021 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix      = var.prefix != "" ? "${var.prefix}-" : ""
  bucket_name = "${local.prefix}pcoip-scripts-${random_id.bucket-name.hex}"
  # Name of Anyware Manager deployment service account key file in bucket
  awm_deployment_sa_file = "awm-deployment-sa-key.json"

  gcp_service_account    = jsondecode(file(var.gcp_credentials_file))["client_email"]
  gcp_project_id         = jsondecode(file(var.gcp_credentials_file))["project_id"]
  ops_linux_setup_script = "ops_setup_linux.sh"
  ops_win_setup_script   = "ops_setup_win.ps1"
  ldaps_cert_filename    = "ldaps_cert.pem"
  log_bucket_name        = "${local.prefix}logging-bucket"
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

resource "google_storage_bucket_object" "awm-deployment-sa-file" {
  bucket = google_storage_bucket.scripts.name
  name   = local.awm_deployment_sa_file
  source = var.awm_deployment_sa_file
}

resource "google_storage_bucket_object" "ops-setup-linux-script" {
  count = var.gcp_ops_agent_enable ? 1 : 0

  bucket = google_storage_bucket.scripts.name
  name   = local.ops_linux_setup_script
  source = "../../../shared/gcp/${local.ops_linux_setup_script}"
}

resource "google_storage_bucket_object" "ops-setup-win-script" {
  count = var.gcp_ops_agent_enable ? 1 : 0

  bucket = google_storage_bucket.scripts.name
  name   = local.ops_win_setup_script
  source = "../../../shared/gcp/${local.ops_win_setup_script}"
}

# Create a log bucket to store selected logs for easier log management, Terraform won't delete the log bucket it created even though
# the log bucket will be removed from .tfstate after destroyed the deployment, so the log bucket deletion has to be done manually,
# the log bucket will be in pending deletion status and will be deleted after 7 days. More info at:
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_bucket_config
# _Default log bucket created by Google cannot be deleted and need to be disabled before creating the deployment to avoid saving the same logs
# in both _Defualt log bucket and the log bucket created by Terraform
resource "google_logging_project_bucket_config" "main" {
  count = var.gcp_ops_agent_enable ? 1 : 0

  bucket_id      = local.log_bucket_name
  project        = local.gcp_project_id
  location       = "global"
  retention_days = var.gcp_logging_retention_days
}

# Create a sink to route instance logs to desinated log bucket
resource "google_logging_project_sink" "instance-sink" {
  count = var.gcp_ops_agent_enable ? 1 : 0

  name        = "${local.prefix}sink"
  destination = "logging.googleapis.com/${google_logging_project_bucket_config.main[0].id}"
  filter      = "resource.type = gce_instance AND resource.labels.project_id = ${local.gcp_project_id}"

  unique_writer_identity = true
}

module "dc" {
  source = "../../../modules/gcp/dc"

  prefix = var.prefix

  pcoip_agent_version     = var.dc_pcoip_agent_version
  pcoip_registration_code = var.pcoip_registration_code
  teradici_download_token = var.teradici_download_token

  gcp_service_account         = local.gcp_service_account
  kms_cryptokey_id            = var.kms_cryptokey_id
  domain_name                 = var.domain_name
  admin_password              = var.dc_admin_password
  safe_mode_admin_password    = var.safe_mode_admin_password
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password
  domain_users_list           = var.domain_users_list
  ldaps_cert_filename         = local.ldaps_cert_filename

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

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = local.ops_win_setup_script

  machine_type = var.dc_machine_type
  disk_size_gb = var.dc_disk_size_gb
  disk_image   = var.dc_disk_image
}

module "awc" {
  source = "../../../modules/gcp/awc"

  prefix = var.prefix

  awc_flag_manager_insecure = var.awc_flag_manager_insecure
  gcp_service_account       = local.gcp_service_account
  kms_cryptokey_id          = var.kms_cryptokey_id
  manager_url               = var.manager_url

  domain_name                 = var.domain_name
  domain_controller_ip        = module.dc.internal-ip
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password
  ldaps_cert_filename         = local.ldaps_cert_filename
  computers_dn                = "dc=${replace(var.domain_name, ".", ",dc=")}"
  users_dn                    = "dc=${replace(var.domain_name, ".", ",dc=")}"

  bucket_name            = google_storage_bucket.scripts.name
  awm_deployment_sa_file = local.awm_deployment_sa_file

  gcp_region_list = [var.gcp_region]
  subnet_list     = [google_compute_subnetwork.awc-subnet.self_link]
  network_tags    = [
    google_compute_firewall.allow-ssh.name,
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-pcoip.name,
  ]

  instance_count_list = [var.awc_instance_count]
  machine_type        = var.awc_machine_type
  disk_size_gb        = var.awc_disk_size_gb
  disk_image          = var.awc_disk_image

  awc_admin_user             = var.awc_admin_user
  awc_admin_ssh_pub_key_file = var.awc_admin_ssh_pub_key_file
  teradici_download_token    = var.teradici_download_token

  tls_key  = var.awc_tls_key
  tls_cert = var.awc_tls_cert

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = local.ops_linux_setup_script

  awc_extra_install_flags = var.awc_extra_install_flags
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

  idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization
  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  network_tags = [
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

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = local.ops_win_setup_script

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

  idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization
  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  network_tags = [
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-rdp.name,
  ]

  instance_count_list = [var.win_std_instance_count]
  instance_name       = var.win_std_instance_name
  machine_type        = var.win_std_machine_type
  disk_size_gb        = var.win_std_disk_size_gb
  disk_image          = var.win_std_disk_image

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = local.ops_win_setup_script

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

  auto_logoff_cpu_utilization            = var.auto_logoff_cpu_utilization
  auto_logoff_enable                     = var.auto_logoff_enable
  auto_logoff_minutes_idle_before_logoff = var.auto_logoff_minutes_idle_before_logoff
  auto_logoff_polling_interval_minutes   = var.auto_logoff_polling_interval_minutes

  idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization
  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  network_tags = [
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

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = local.ops_linux_setup_script

  ws_admin_user             = var.centos_admin_user
  ws_admin_ssh_pub_key_file = var.centos_admin_ssh_pub_key_file

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

  auto_logoff_cpu_utilization            = var.auto_logoff_cpu_utilization
  auto_logoff_enable                     = var.auto_logoff_enable
  auto_logoff_minutes_idle_before_logoff = var.auto_logoff_minutes_idle_before_logoff
  auto_logoff_polling_interval_minutes   = var.auto_logoff_polling_interval_minutes

  idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization
  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  network_tags = [
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-ssh.name,
  ]

  instance_count_list = [var.centos_std_instance_count]
  instance_name       = var.centos_std_instance_name
  machine_type        = var.centos_std_machine_type
  disk_size_gb        = var.centos_std_disk_size_gb
  disk_image          = var.centos_std_disk_image

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = local.ops_linux_setup_script

  ws_admin_user             = var.centos_admin_user
  ws_admin_ssh_pub_key_file = var.centos_admin_ssh_pub_key_file

  depends_on = [google_compute_router_nat.nat]
}
