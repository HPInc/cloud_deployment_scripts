/*
 * Copyright Teradici Corporation 2020-2021;  © Copyright 2022-2024 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  admin_ssh_key_name     = "${local.prefix}${var.admin_ssh_key_name}"

  cloudwatch_setup_rpm_script = "cloudwatch_setup_rpm.sh"
  cloudwatch_setup_win_script = "cloudwatch_setup_win.ps1"
  ldaps_cert_filename         = "ldaps_cert.pem"
}

resource "aws_key_pair" "anyware_admin" {
  key_name   = local.admin_ssh_key_name
  public_key = file(var.admin_ssh_pub_key_file)
}

module "shared-bucket" {
  source = "../../../modules/aws/shared-bucket"
  prefix = var.prefix
}

resource "aws_s3_object" "cloudwatch-setup-rpm-script" {
  count = var.cloudwatch_enable ? 1 : 0

  bucket = module.shared-bucket.bucket.id
  key    = local.cloudwatch_setup_rpm_script
  source = "../../../shared/aws/${local.cloudwatch_setup_rpm_script}"
}

resource "aws_s3_object" "cloudwatch-setup-win-script" {
  count = var.cloudwatch_enable ? 1 : 0

  bucket = module.shared-bucket.bucket.id
  key    = local.cloudwatch_setup_win_script
  source = "../../../shared/aws/${local.cloudwatch_setup_win_script}"
}

module "dc" {
  source = "../../../modules/aws/dc"

  prefix = var.prefix

  pcoip_agent_install            = var.dc_pcoip_agent_install
  pcoip_agent_version            = var.dc_pcoip_agent_version
  pcoip_registration_code_id     = aws_secretsmanager_secret.pcoip_registration_code.id
  teradici_download_token        = var.teradici_download_token
  aws_region                     = var.aws_region

  domain_name                    = var.domain_name
  admin_password_id              = aws_secretsmanager_secret.admin_password.id
  safe_mode_admin_password_id    = aws_secretsmanager_secret.safe_mode_admin_password.id
  ad_service_account_username    = var.ad_service_account_username
  ad_service_account_password_id = aws_secretsmanager_secret.ad_service_account_password.id
  domain_users_list              = var.domain_users_list
  ldaps_cert_filename            = local.ldaps_cert_filename

  bucket_name = module.shared-bucket.bucket.id
  subnet      = aws_subnet.dc-subnet.id
  security_group_ids =concat(
    [aws_security_group.allow-internal.id],
    var.enable_rdp  ? [aws_security_group.allow-rdp[0].id]  : [],
    var.enable_icmp ? [aws_security_group.allow-icmp[0].id] : [],
  )

  instance_type = var.dc_instance_type
  disk_size_gb  = var.dc_disk_size_gb

  ami_owner = var.dc_ami_owner
  ami_name  = var.dc_ami_name

  aws_ssm_enable = var.aws_ssm_enable

  cloudwatch_enable       = var.cloudwatch_enable
  cloudwatch_setup_script = local.cloudwatch_setup_win_script
}

module "awc" {
  source = "../../../modules/aws/awc"

  prefix = var.prefix

  awm_deployment_sa_file_id     = aws_secretsmanager_secret.awm_deployment_sa_file.id
  aws_region                    = var.aws_region
  awc_flag_manager_insecure     = var.awc_flag_manager_insecure
  manager_url                   = var.manager_url

  domain_name                    = var.domain_name
  domain_controller_ip           = module.dc.internal-ip
  ad_service_account_username    = var.ad_service_account_username
  ad_service_account_password_id = aws_secretsmanager_secret.ad_service_account_password.id
  ldaps_cert_filename            = local.ldaps_cert_filename
  computers_dn                   = "dc=${replace(var.domain_name, ".", ",dc=")}"
  users_dn                       = "dc=${replace(var.domain_name, ".", ",dc=")}"

  zone_list           = [aws_subnet.awc-subnet.availability_zone]
  subnet_list         = [aws_subnet.awc-subnet.id]
  instance_count_list = [var.awc_instance_count]

  security_group_ids = concat(
    [aws_security_group.allow-internal.id],
    [aws_security_group.allow-pcoip.id],
    var.enable_ssh  ? [aws_security_group.allow-ssh[0].id]  : [],
    var.enable_icmp ? [aws_security_group.allow-icmp[0].id] : [],
  )


  bucket_name   = module.shared-bucket.bucket.id
  instance_type = var.awc_instance_type
  disk_size_gb  = var.awc_disk_size_gb

  ami_owner = var.awc_ami_owner
  ami_name  = var.awc_ami_name

  teradici_download_token = var.teradici_download_token

  admin_ssh_key_name = local.admin_ssh_key_name

  tls_key  = var.tls_key
  tls_cert = var.tls_cert

  awc_extra_install_flags = var.awc_extra_install_flags

  aws_ssm_enable          = var.aws_ssm_enable
  cloudwatch_enable       = var.cloudwatch_enable
  cloudwatch_setup_script = local.cloudwatch_setup_rpm_script

  rocky_gfx_instance_count = var.rocky_gfx_instance_count
  rocky_std_instance_count = var.rocky_std_instance_count
  win_gfx_instance_count   = var.win_gfx_instance_count
  win_std_instance_count   = var.win_std_instance_count
}

module "win-gfx" {
  source = "../../../modules/aws/win-gfx"

  prefix = var.prefix

  aws_region             = var.aws_region

  pcoip_registration_code_id = aws_secretsmanager_secret.pcoip_registration_code.id
  teradici_download_token    = var.teradici_download_token
  pcoip_agent_version        = var.win_gfx_pcoip_agent_version

  domain_name                    = var.domain_name
  admin_password_id              = aws_secretsmanager_secret.admin_password.id
  ad_service_account_username    = var.ad_service_account_username
  ad_service_account_password_id = aws_secretsmanager_secret.ad_service_account_password.id

  bucket_name      = module.shared-bucket.bucket.id
  subnet           = aws_subnet.ws-subnet.id
  enable_public_ip = var.enable_workstation_public_ip
  security_group_ids = concat(
    [aws_security_group.allow-internal.id],
    var.enable_icmp ? [aws_security_group.allow-icmp[0].id] : [],
    var.enable_rdp  ? [aws_security_group.allow-rdp[0].id]  : [],
  )

  idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization
  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  instance_count = var.win_gfx_instance_count
  instance_name  = var.win_gfx_instance_name
  instance_type  = var.win_gfx_instance_type
  disk_size_gb   = var.win_gfx_disk_size_gb

  ami_owner = var.win_gfx_ami_owner
  ami_name  = var.win_gfx_ami_name

  aws_ssm_enable = var.aws_ssm_enable

  cloudwatch_enable       = var.cloudwatch_enable
  cloudwatch_setup_script = local.cloudwatch_setup_win_script

  depends_on = [aws_nat_gateway.nat]
}

module "win-std" {
  source = "../../../modules/aws/win-std"

  prefix = var.prefix

  aws_region             = var.aws_region

  pcoip_registration_code_id = aws_secretsmanager_secret.pcoip_registration_code.id
  teradici_download_token    = var.teradici_download_token
  pcoip_agent_version        = var.win_std_pcoip_agent_version

  domain_name                    = var.domain_name
  admin_password_id              = aws_secretsmanager_secret.admin_password.id
  ad_service_account_username    = var.ad_service_account_username
  ad_service_account_password_id = aws_secretsmanager_secret.ad_service_account_password.id

  bucket_name      = module.shared-bucket.bucket.id
  subnet           = aws_subnet.ws-subnet.id
  enable_public_ip = var.enable_workstation_public_ip
  security_group_ids = concat(
    [aws_security_group.allow-internal.id],
    var.enable_icmp ? [aws_security_group.allow-icmp[0].id] : [],
    var.enable_rdp  ? [aws_security_group.allow-rdp[0].id]  : [],
  )

  idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization
  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  instance_count = var.win_std_instance_count
  instance_name  = var.win_std_instance_name
  instance_type  = var.win_std_instance_type
  disk_size_gb   = var.win_std_disk_size_gb

  ami_owner = var.win_std_ami_owner
  ami_name  = var.win_std_ami_name

  aws_ssm_enable = var.aws_ssm_enable

  cloudwatch_enable       = var.cloudwatch_enable
  cloudwatch_setup_script = local.cloudwatch_setup_win_script

  depends_on = [aws_nat_gateway.nat]
}

module "rocky-gfx" {
  source = "../../../modules/aws/rocky-gfx"

  prefix = var.prefix

  aws_region             = var.aws_region

  pcoip_registration_code_id = aws_secretsmanager_secret.pcoip_registration_code.id
  teradici_download_token    = var.teradici_download_token

  domain_name                    = var.domain_name
  domain_controller_ip           = module.dc.internal-ip
  ad_service_account_username    = var.ad_service_account_username
  ad_service_account_password_id = aws_secretsmanager_secret.ad_service_account_password.id

  bucket_name      = module.shared-bucket.bucket.id
  subnet           = aws_subnet.ws-subnet.id
  enable_public_ip = var.enable_workstation_public_ip
  security_group_ids = concat(
    [aws_security_group.allow-internal.id],
    var.enable_icmp ? [aws_security_group.allow-icmp[0].id] : [],
    var.enable_ssh  ? [aws_security_group.allow-ssh[0].id]  : [],
  )

  auto_logoff_cpu_utilization            = var.auto_logoff_cpu_utilization
  auto_logoff_enable                     = var.auto_logoff_enable
  auto_logoff_minutes_idle_before_logoff = var.auto_logoff_minutes_idle_before_logoff
  auto_logoff_polling_interval_minutes   = var.auto_logoff_polling_interval_minutes

  idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization
  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  instance_count = var.rocky_gfx_instance_count
  instance_name  = var.rocky_gfx_instance_name
  instance_type  = var.rocky_gfx_instance_type
  disk_size_gb   = var.rocky_gfx_disk_size_gb

  ami_owner = var.rocky_gfx_ami_owner
  ami_name  = var.rocky_gfx_ami_name

  admin_ssh_key_name = local.admin_ssh_key_name

  aws_ssm_enable = var.aws_ssm_enable

  cloudwatch_enable       = var.cloudwatch_enable
  cloudwatch_setup_script = local.cloudwatch_setup_rpm_script

  depends_on = [aws_nat_gateway.nat]
}

module "rocky-std" {
  source = "../../../modules/aws/rocky-std"

  prefix = var.prefix

  aws_region             = var.aws_region

  pcoip_registration_code_id = aws_secretsmanager_secret.pcoip_registration_code.id
  teradici_download_token    = var.teradici_download_token

  domain_name                    = var.domain_name
  domain_controller_ip           = module.dc.internal-ip
  ad_service_account_username    = var.ad_service_account_username
  ad_service_account_password_id = aws_secretsmanager_secret.ad_service_account_password.id

  bucket_name      = module.shared-bucket.bucket.id
  subnet           = aws_subnet.ws-subnet.id
  enable_public_ip = var.enable_workstation_public_ip
  security_group_ids = concat(
    [aws_security_group.allow-internal.id],
    var.enable_icmp ? [aws_security_group.allow-icmp[0].id] : [],
    var.enable_ssh  ? [aws_security_group.allow-ssh[0].id]  : [],
  )

  auto_logoff_cpu_utilization            = var.auto_logoff_cpu_utilization
  auto_logoff_enable                     = var.auto_logoff_enable
  auto_logoff_minutes_idle_before_logoff = var.auto_logoff_minutes_idle_before_logoff
  auto_logoff_polling_interval_minutes   = var.auto_logoff_polling_interval_minutes

  idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization
  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  instance_count = var.rocky_std_instance_count
  instance_name  = var.rocky_std_instance_name
  instance_type  = var.rocky_std_instance_type
  disk_size_gb   = var.rocky_std_disk_size_gb

  ami_owner = var.rocky_std_ami_owner
  ami_name  = var.rocky_std_ami_name

  admin_ssh_key_name = local.admin_ssh_key_name

  aws_ssm_enable = var.aws_ssm_enable

  cloudwatch_enable       = var.cloudwatch_enable
  cloudwatch_setup_script = local.cloudwatch_setup_rpm_script

  depends_on = [aws_nat_gateway.nat]
}
