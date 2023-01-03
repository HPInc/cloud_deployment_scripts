/*
 * Copyright Teradici Corporation 2020-2021;  © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix      = var.prefix != "" ? "${var.prefix}-" : ""
  bucket_name = "${local.prefix}pcoip-scripts-${random_id.bucket-name.hex}"
  # Name of Anyware Manager deployment service account key file in bucket
  awm_deployment_sa_file = "awm-deployment-sa-key.json"
  # Name of GCP service account key file in bucket
  gcp_sa_file = "gcp-sa-key.json"

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

resource "google_storage_bucket_object" "gcp-sa-file" {
  bucket = google_storage_bucket.scripts.name
  name   = local.gcp_sa_file
  source = var.awm_gcp_credentials_file
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

  admin_password              = var.dc_admin_password
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password
  domain_name                 = var.domain_name
  domain_users_list           = var.domain_users_list
  gcp_service_account         = local.gcp_service_account
  kms_cryptokey_id            = var.kms_cryptokey_id
  safe_mode_admin_password    = var.safe_mode_admin_password
  ldaps_cert_filename         = local.ldaps_cert_filename

  bucket_name = google_storage_bucket.scripts.name
  gcp_zone    = var.gcp_zone
  subnet      = google_compute_subnetwork.dc-subnet.self_link
  private_ip  = var.dc_private_ip
  network_tags = [
    google_compute_firewall.allow-google-dns.name,
    google_compute_firewall.allow-rdp.name,
    google_compute_firewall.allow-winrm.name,
    google_compute_firewall.allow-icmp.name,
  ]

  machine_type = var.dc_machine_type
  disk_size_gb = var.dc_disk_size_gb

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = local.ops_win_setup_script

  disk_image = var.dc_disk_image
}

module "awm" {
  source = "../../../modules/gcp/awm"

  prefix = var.prefix

  gcp_service_account     = local.gcp_service_account
  kms_cryptokey_id        = var.kms_cryptokey_id
  pcoip_registration_code = var.pcoip_registration_code
  awm_admin_password      = var.awm_admin_password
  teradici_download_token = var.teradici_download_token

  bucket_name            = google_storage_bucket.scripts.name
  awm_deployment_sa_file = local.awm_deployment_sa_file
  gcp_sa_file            = local.gcp_sa_file

  gcp_region = var.gcp_region
  gcp_zone   = var.gcp_zone
  subnet     = google_compute_subnetwork.awm-subnet.self_link
  network_tags = [
    google_compute_firewall.allow-ssh.name,
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-https.name,
  ]

  machine_type = var.awm_machine_type
  disk_size_gb = var.awm_disk_size_gb

  disk_image = var.awm_disk_image

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = local.ops_linux_setup_script

  awm_admin_user             = var.awm_admin_user
  awm_admin_ssh_pub_key_file = var.awm_admin_ssh_pub_key_file
}

module "awc-igm" {
  source = "../../../modules/gcp/awc-igm"

  prefix = var.prefix

  awc_flag_manager_insecure = true
  gcp_service_account       = local.gcp_service_account
  kms_cryptokey_id          = var.kms_cryptokey_id
  manager_url               = "https://${module.awm.internal-ip}"

  domain_name                 = var.domain_name
  domain_controller_ip        = module.dc.internal-ip
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password
  ldaps_cert_filename         = local.ldaps_cert_filename
  computers_dn                = "dc=${replace(var.domain_name, ".", ",dc=")}"
  users_dn                    = "dc=${replace(var.domain_name, ".", ",dc=")}"

  bucket_name            = google_storage_bucket.scripts.name
  awm_deployment_sa_file = local.awm_deployment_sa_file

  gcp_region_list = var.awc_region_list
  subnet_list     = google_compute_subnetwork.awc-subnets[*].self_link
  network_tags = [
    google_compute_firewall.allow-google-health-check.name,
    google_compute_firewall.allow-ssh.name,
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-pcoip.name,
  ]

  instance_count_list = var.awc_instance_count_list
  machine_type        = var.awc_machine_type
  disk_size_gb        = var.awc_disk_size_gb

  disk_image = var.awc_disk_image

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = local.ops_linux_setup_script

  awc_admin_user             = var.awc_admin_user
  awc_admin_ssh_pub_key_file = var.awc_admin_ssh_pub_key_file
  awc_extra_install_flags    = var.awc_extra_install_flags
  teradici_download_token    = var.teradici_download_token
}

resource "google_compute_https_health_check" "awc-hchk" {
  name               = "${local.prefix}hchk-awc"
  request_path       = var.awc_health_check["path"]
  port               = var.awc_health_check["port"]
  check_interval_sec = var.awc_health_check["interval_sec"]
  timeout_sec        = var.awc_health_check["timeout_sec"]
}

resource "google_compute_backend_service" "awc-bkend-service" {
  name                    = "${local.prefix}bkend-service-awc"
  port_name               = "https"
  protocol                = "HTTPS"
  session_affinity        = "GENERATED_COOKIE"
  affinity_cookie_ttl_sec = 3600

  dynamic "backend" {
    for_each = module.awc-igm.awc-igm
    iterator = i

    content {
      balancing_mode = "UTILIZATION"

      # Wants instanceGroup instead of instanceGroupManager
      group = replace(i.value, "Manager", "")
    }
  }

  health_checks = [google_compute_https_health_check.awc-hchk.self_link]
}

resource "google_compute_url_map" "awc-urlmap" {
  name            = "${local.prefix}urlmap-awc"
  default_service = google_compute_backend_service.awc-bkend-service.self_link
}

resource "tls_private_key" "tls-key" {
  count = var.glb_tls_key == "" ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_self_signed_cert" "tls-cert" {
  count = var.glb_tls_cert == "" ? 1 : 0

  private_key_pem = tls_private_key.tls-key[0].private_key_pem

  subject {
    common_name = var.domain_name
  }

  validity_period_hours = 8760

  allowed_uses = [
    "cert_signing",
    "digital_signature",
    "key_encipherment",
  ]
}

resource "google_compute_ssl_certificate" "tls-cert" {
  name        = "${local.prefix}tls-cert"
  private_key = var.glb_tls_key == "" ? tls_private_key.tls-key[0].private_key_pem : file(var.glb_tls_key)
  certificate = var.glb_tls_cert == "" ? tls_self_signed_cert.tls-cert[0].cert_pem : file(var.glb_tls_cert)
}

resource "google_compute_target_https_proxy" "awc-proxy" {
  name             = "${local.prefix}proxy-awc"
  url_map          = google_compute_url_map.awc-urlmap.self_link
  ssl_certificates = [google_compute_ssl_certificate.tls-cert.self_link]
}

resource "google_compute_global_forwarding_rule" "awc-fwdrule" {
  name = "${local.prefix}fwdrule-awc"

  #ip_protocol = "TCP"
  port_range = "443"
  target     = google_compute_target_https_proxy.awc-proxy.self_link
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
  zone_list        = var.ws_zone_list
  subnet_list      = google_compute_subnetwork.ws-subnets[*].self_link
  enable_public_ip = var.enable_workstation_public_ip

  idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization
  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  network_tags = [
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-rdp.name,
  ]

  instance_count_list = var.win_gfx_instance_count_list
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
  zone_list        = var.ws_zone_list
  subnet_list      = google_compute_subnetwork.ws-subnets[*].self_link
  enable_public_ip = var.enable_workstation_public_ip

  idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization
  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  network_tags = [
    google_compute_firewall.allow-icmp.name,
    google_compute_firewall.allow-rdp.name,
  ]

  instance_count_list = var.win_std_instance_count_list
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
  zone_list        = var.ws_zone_list
  subnet_list      = google_compute_subnetwork.ws-subnets[*].self_link
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

  instance_count_list = var.centos_gfx_instance_count_list
  instance_name       = var.centos_gfx_instance_name
  machine_type        = var.centos_gfx_machine_type
  accelerator_type    = var.centos_gfx_accelerator_type
  accelerator_count   = var.centos_gfx_accelerator_count
  disk_size_gb        = var.centos_gfx_disk_size_gb
  disk_image          = var.centos_gfx_disk_image

  ws_admin_user             = var.centos_admin_user
  ws_admin_ssh_pub_key_file = var.centos_admin_ssh_pub_key_file

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = local.ops_linux_setup_script

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
  zone_list        = var.ws_zone_list
  subnet_list      = google_compute_subnetwork.ws-subnets[*].self_link
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

  instance_count_list = var.centos_std_instance_count_list
  instance_name       = var.centos_std_instance_name
  machine_type        = var.centos_std_machine_type
  disk_size_gb        = var.centos_std_disk_size_gb
  disk_image          = var.centos_std_disk_image

  ws_admin_user             = var.centos_admin_user
  ws_admin_ssh_pub_key_file = var.centos_admin_ssh_pub_key_file

  gcp_ops_agent_enable = var.gcp_ops_agent_enable
  ops_setup_script     = local.ops_linux_setup_script

  depends_on = [google_compute_router_nat.nat]
}
