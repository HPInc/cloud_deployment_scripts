/*
 * Copyright Teradici Corporation 2020-2021;  © Copyright 2021-2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix             = var.prefix != "" ? "${var.prefix}-" : ""
  bucket_name        = "${local.prefix}pcoip-scripts-${random_id.bucket-name.hex}"
  # Name of CAS Manager deployment service account key file in bucket
  cas_mgr_deployment_sa_file = "cas-mgr-deployment-sa-key.json"
  # ES - Use a predefined keypair if one is passed in, otherwise create one
  admin_ssh_key_name = var.keypair_name != "" ? var.keypair_name : "${local.prefix}${var.admin_ssh_key_name}"
  cas_mgr_aws_credentials_file = "cas-mgr-aws-credentials.ini"
  cas_mgr_aws_credentials_string = var.cas_mgr_aws_credentials_string
  
  cloudwatch_setup_rpm_script = "cloudwatch_setup_rpm.sh"
  cloudwatch_setup_win_script = "cloudwatch_setup_win.ps1"
  ldaps_cert_filename = "ldaps_cert.pem"
}

# Use a predefined keypair if one is passed in, otherwise create one
resource "aws_key_pair" "cas_admin" {
  count = var.keypair_name != "" ? 0 : 1
  key_name   = local.admin_ssh_key_name
  public_key = file(var.admin_ssh_pub_key_file)
}

resource "random_id" "bucket-name" {
  byte_length = 3
}

resource "aws_s3_bucket" "scripts" {
  bucket        = local.bucket_name
  acl           = "private"
  force_destroy = true

  tags = {
    Name = local.bucket_name
  }
}

resource "local_file" "aws_credentials_tmp" {
    content  = var.cas_mgr_aws_credentials_string
    filename = "${path.module}/aws_credentials.tmp"
}

resource "aws_s3_bucket_object" "cas_mgr_aws_credentials_file" {
  bucket = aws_s3_bucket.scripts.bucket
  key    = local.cas_mgr_aws_credentials_file
  source = var.cas_mgr_aws_credentials_string != "" ? local_file.aws_credentials_tmp.filename :  var.cas_mgr_aws_credentials_file
}

resource "aws_s3_bucket_object" "cloudwatch-setup-rpm-script" {
  count = var.cloudwatch_enable ? 1 : 0

  bucket = aws_s3_bucket.scripts.id
  key    = local.cloudwatch_setup_rpm_script
  source = "${path.module}/../../../shared/aws/${local.cloudwatch_setup_rpm_script}"
}

resource "aws_s3_bucket_object" "cloudwatch-setup-win-script" {
  count = var.cloudwatch_enable ? 1 : 0

  bucket = aws_s3_bucket.scripts.id
  key    = local.cloudwatch_setup_win_script
  source = "${path.module}/../../../shared/aws/${local.cloudwatch_setup_win_script}"
}

module "dc" {
  source = "../../../modules/aws/dc"

  prefix = var.prefix
  
  pcoip_agent_version         = var.dc_pcoip_agent_version
  pcoip_registration_code     = var.pcoip_registration_code
  teradici_download_token     = var.teradici_download_token
  
  customer_master_key_id      = var.customer_master_key_id
  domain_name                 = var.domain_name
  admin_password              = var.dc_admin_password
  safe_mode_admin_password    = var.safe_mode_admin_password
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password
  domain_users_list           = var.domain_users_list
  ldaps_cert_filename         = local.ldaps_cert_filename

  bucket_name        = aws_s3_bucket.scripts.id
  # NOTE: artifically forcing the DC into a separate subnet; see notes in
  # the networking.tf module
  subnet             = var.public_subnet_ids[1] # aws_subnet.dc-subnet.id
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-rdp.id,
    aws_security_group.allow-winrm.id,
    aws_security_group.allow-icmp.id,
  ]

  instance_type = var.dc_instance_type
  disk_size_gb  = var.dc_disk_size_gb

  ami_owner = var.dc_ami_owner
  ami_name  = var.dc_ami_name
  
  aws_ssm_enable = var.aws_ssm_enable

  cloudwatch_enable       = var.cloudwatch_enable
  cloudwatch_setup_script = local.cloudwatch_setup_win_script
}

module "cas-mgr" {
  source = "../../../modules/aws/cas-mgr"

  prefix = var.prefix

  aws_region              = var.aws_region
  customer_master_key_id  = var.customer_master_key_id
  pcoip_registration_code = var.pcoip_registration_code
  cas_mgr_admin_password  = var.cas_mgr_admin_password
  teradici_download_token = var.teradici_download_token

  bucket_name                  = aws_s3_bucket.scripts.id
  cas_mgr_aws_credentials_file = local.cas_mgr_aws_credentials_file
  cas_mgr_deployment_sa_file   = local.cas_mgr_deployment_sa_file

  subnet = var.public_subnet_ids[0] # aws_subnet.cas-mgr-subnet.id
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-http.id,
    aws_security_group.allow-ssh.id,
    aws_security_group.allow-icmp.id,
  ]

  instance_type = var.cas_mgr_instance_type
  disk_size_gb  = var.cas_mgr_disk_size_gb

  ami_owner = var.cas_mgr_ami_owner
  ami_name  = var.cas_mgr_ami_name

  admin_ssh_key_name = local.admin_ssh_key_name
  
  aws_ssm_enable = var.aws_ssm_enable

  cloudwatch_enable       = var.cloudwatch_enable
  cloudwatch_setup_script = local.cloudwatch_setup_rpm_script
}

module "cas-connector" {
  source = "../../../modules/aws/cas-connector"

  prefix = var.prefix

  aws_region                 = var.aws_region
  customer_master_key_id     = var.customer_master_key_id
  cas_mgr_url                = "https://${module.cas-mgr.internal-ip}"
  cas_mgr_insecure           = true
  cas_mgr_deployment_sa_file = local.cas_mgr_deployment_sa_file

  domain_name                 = var.domain_name
  domain_controller_ip        = module.dc.internal-ip
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password
  ldaps_cert_filename         = local.ldaps_cert_filename
  computers_dn                = "dc=${replace(var.domain_name, ".", ",dc=")}"
  users_dn                    = "dc=${replace(var.domain_name, ".", ",dc=")}"

  zone_list           = [data.aws_availability_zones.available_az.names[0]] # [aws_subnet.cas-connector-subnet.availability_zone]
  subnet_list         = var.public_subnet_ids # [aws_subnet.cas-connector-subnet.id]
  instance_count_list = [var.cas_connector_instance_count]

  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-ssh.id,
    aws_security_group.allow-icmp.id,
    aws_security_group.allow-pcoip.id,
  ]

  bucket_name   = aws_s3_bucket.scripts.id
  instance_type = var.cas_connector_instance_type
  disk_size_gb  = var.cas_connector_disk_size_gb

  ami_owner = var.cas_connector_ami_owner
  ami_name  = var.cas_connector_ami_name
  
  teradici_download_token = var.teradici_download_token

  admin_ssh_key_name = local.admin_ssh_key_name

  tls_key  = var.tls_key
  tls_cert = var.tls_cert

  cas_connector_extra_install_flags = var.cas_connector_extra_install_flags
  
  aws_ssm_enable = var.aws_ssm_enable

  cloudwatch_enable       = var.cloudwatch_enable
  cloudwatch_setup_script = local.cloudwatch_setup_rpm_script
}

module "win-gfx" {
  source = "../../../modules/aws/win-gfx"

  prefix = var.prefix

  customer_master_key_id = var.customer_master_key_id

  pcoip_registration_code = var.pcoip_registration_code
  teradici_download_token = var.teradici_download_token
  pcoip_agent_version     = var.win_gfx_pcoip_agent_version

  domain_name                 = var.domain_name
  admin_password              = var.dc_admin_password
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name        = aws_s3_bucket.scripts.id
  subnet             = var.public_subnet_ids[0] # aws_subnet.ws-subnet.id
  enable_public_ip   = var.enable_workstation_public_ip
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-icmp.id,
    aws_security_group.allow-rdp.id,
  ]

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

  # Removing this dependency since the nat gateway is being created upstream
  #depends_on = [aws_nat_gateway.nat]
}

module "win-std" {
  source = "../../../modules/aws/win-std"

  prefix = var.prefix

  customer_master_key_id = var.customer_master_key_id

  pcoip_registration_code = var.pcoip_registration_code
  teradici_download_token = var.teradici_download_token
  pcoip_agent_version     = var.win_std_pcoip_agent_version

  domain_name                 = var.domain_name
  admin_password              = var.dc_admin_password
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name        = aws_s3_bucket.scripts.id
  subnet             = var.public_subnet_ids[0] # aws_subnet.ws-subnet.id
  enable_public_ip   = var.enable_workstation_public_ip
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-icmp.id,
    aws_security_group.allow-rdp.id,
  ]

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

  # Removing this dependency since the nat gateway is being created upstream
  #depends_on = [aws_nat_gateway.nat]
}

module "centos-gfx" {
  source = "../../../modules/aws/centos-gfx"

  prefix = var.prefix

  aws_region             = var.aws_region
  customer_master_key_id = var.customer_master_key_id

  pcoip_registration_code = var.pcoip_registration_code
  teradici_download_token = var.teradici_download_token

  domain_name                 = var.domain_name
  domain_controller_ip        = module.dc.internal-ip
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name        = aws_s3_bucket.scripts.id
  subnet             = var.public_subnet_ids[0] # aws_subnet.ws-subnet.id
  enable_public_ip   = var.enable_workstation_public_ip
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-icmp.id,
    aws_security_group.allow-ssh.id,
  ]

  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  instance_count = var.centos_gfx_instance_count
  instance_name  = var.centos_gfx_instance_name
  instance_type  = var.centos_gfx_instance_type
  disk_size_gb   = var.centos_gfx_disk_size_gb

  ami_owner = var.centos_gfx_ami_owner
  ami_name  = var.centos_gfx_ami_name

  admin_ssh_key_name = local.admin_ssh_key_name
  
  aws_ssm_enable = var.aws_ssm_enable

  cloudwatch_enable       = var.cloudwatch_enable
  cloudwatch_setup_script = local.cloudwatch_setup_rpm_script

  # Removing this dependency since the nat gateway is being created upstream
  #depends_on = [aws_nat_gateway.nat]
}

module "centos-std" {
  source = "../../../modules/aws/centos-std"

  prefix = var.prefix

  aws_region             = var.aws_region
  customer_master_key_id = var.customer_master_key_id

  pcoip_registration_code = var.pcoip_registration_code
  teradici_download_token = var.teradici_download_token

  domain_name                 = var.domain_name
  domain_controller_ip        = module.dc.internal-ip
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name        = aws_s3_bucket.scripts.id
  subnet             = var.public_subnet_ids[0] # aws_subnet.ws-subnet.id
  enable_public_ip   = var.enable_workstation_public_ip
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-icmp.id,
    aws_security_group.allow-ssh.id,
  ]

  idle_shutdown_enable                       = var.idle_shutdown_enable
  idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown
  idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes

  instance_count = var.centos_std_instance_count
  instance_name  = var.centos_std_instance_name
  instance_type  = var.centos_std_instance_type
  disk_size_gb   = var.centos_std_disk_size_gb

  ami_owner = var.centos_std_ami_owner
  ami_name  = var.centos_std_ami_name

  admin_ssh_key_name = local.admin_ssh_key_name
  
  aws_ssm_enable = var.aws_ssm_enable

  cloudwatch_enable       = var.cloudwatch_enable
  cloudwatch_setup_script = local.cloudwatch_setup_rpm_script

  # Removing this dependency since the nat gateway is being created upstream
  #depends_on = [aws_nat_gateway.nat]
}
