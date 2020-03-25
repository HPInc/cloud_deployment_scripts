/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  bucket_name = "${local.prefix}pcoip-scripts-${random_id.bucket-name.hex}"
}

resource "random_id" "bucket-name" {
  byte_length = 3
}

resource "aws_s3_bucket" "scripts" {
  bucket        = local.bucket_name
  region        = var.aws_region
  acl           = "private"
  force_destroy = true

  tags = {
    Name = local.bucket_name
  }
}

module "dc" {
  source = "../../../modules/aws/dc"

  prefix = var.prefix

  customer_master_key_id      = var.customer_master_key_id
  domain_name                 = var.domain_name
  admin_password              = var.dc_admin_password
  safe_mode_admin_password    = var.safe_mode_admin_password
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password
  domain_users_list           = var.domain_users_list

  bucket_name        = aws_s3_bucket.scripts.id
  subnet             = aws_subnet.dc-subnet.id
  private_ip         = var.dc_private_ip
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
}

resource "aws_key_pair" "cam_admin" {
  key_name   = var.admin_ssh_key_name
  public_key = file(var.admin_ssh_pub_key_file)
}

resource "aws_lb" "cac-alb" {
  name               = "${local.prefix}cac-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [
    data.aws_security_group.default.id,
    aws_security_group.allow-ssh.id,
    aws_security_group.allow-icmp.id,
    aws_security_group.allow-https.id,
    aws_security_group.allow-pcoip.id,
  ]
  subnets            = aws_subnet.cac-subnets[*].id
}

resource "aws_lb_target_group" "cac-tg" {
  name        = "${local.prefix}cac-tg"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = aws_vpc.vpc.id

  stickiness {
    type = "lb_cookie"
  }

  #TODO add health check
}

resource "aws_acm_certificate" "ssl-cert" {
  private_key      = file(var.ssl_key)
  certificate_body = file(var.ssl_cert)

  tags = {
    Name = "${local.prefix}ssl-cert"
  }
}

resource "aws_lb_listener" "alb-listener" {
  load_balancer_arn = aws_lb.cac-alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.ssl-cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cac-tg.arn
  }
}

module "cac" {
  source = "../../../modules/aws/cac"

  prefix = var.prefix

  aws_region              = var.aws_region
  customer_master_key_id  = var.customer_master_key_id
  cam_url                 = var.cam_url
  pcoip_registration_code = var.pcoip_registration_code
  cac_token               = var.cac_token

  domain_name                 = var.domain_name
  domain_controller_ip        = module.dc.internal-ip
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  zone_list           = aws_subnet.cac-subnets[*].availability_zone
  subnet_list         = aws_subnet.cac-subnets[*].id
  instance_count_list = var.cac_instance_count_list

  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-ssh.id,
    aws_security_group.allow-icmp.id,
    aws_security_group.allow-https.id,
    aws_security_group.allow-pcoip.id,
  ]

  bucket_name    = aws_s3_bucket.scripts.id
  instance_type  = var.cac_instance_type
  disk_size_gb   = var.cac_disk_size_gb

  ami_owner = var.cac_ami_owner
  ami_name  = var.cac_ami_name

  admin_ssh_key_name = var.admin_ssh_key_name
}

resource "aws_lb_target_group_attachment" "cac-tg-attachement" {
  count            = length(module.cac.instance-id)

  target_group_arn = aws_lb_target_group.cac-tg.arn
  target_id        = module.cac.instance-id[count.index]
  port             = 443
}

module "win-gfx" {
  source = "../../../modules/aws/win-gfx"

  instance_count = var.win_gfx_instance_count

  prefix = var.prefix

  customer_master_key_id = var.customer_master_key_id

  pcoip_registration_code = var.pcoip_registration_code

  domain_name                 = var.domain_name
  admin_password              = var.dc_admin_password
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name        = aws_s3_bucket.scripts.id
  subnet             = aws_subnet.ws-subnet.id
  enable_public_ip   = var.enable_workstation_public_ip
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-icmp.id,
    aws_security_group.allow-rdp.id,
  ]

  instance_type     = var.win_gfx_instance_type
  disk_size_gb      = var.win_gfx_disk_size_gb

  ami_owner = var.win_gfx_ami_owner
  ami_name  = var.win_gfx_ami_name

  depends_on_hack = [aws_nat_gateway.nat.id]
}

module "win-std" {
  source = "../../../modules/aws/win-std"

  instance_count = var.win_std_instance_count

  prefix = var.prefix

  customer_master_key_id = var.customer_master_key_id

  pcoip_registration_code = var.pcoip_registration_code

  domain_name                 = var.domain_name
  admin_password              = var.dc_admin_password
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name        = aws_s3_bucket.scripts.id
  subnet             = aws_subnet.ws-subnet.id
  enable_public_ip   = var.enable_workstation_public_ip
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-icmp.id,
    aws_security_group.allow-rdp.id,
  ]

  instance_type     = var.win_std_instance_type
  disk_size_gb      = var.win_std_disk_size_gb

  ami_owner = var.win_std_ami_owner
  ami_name  = var.win_std_ami_name

  depends_on_hack = [aws_nat_gateway.nat.id]
}

module "centos-gfx" {
  source = "../../../modules/aws/centos-gfx"

  instance_count = var.centos_gfx_instance_count

  prefix = var.prefix

  customer_master_key_id = var.customer_master_key_id

  pcoip_registration_code = var.pcoip_registration_code

  domain_name                 = var.domain_name
  domain_controller_ip        = module.dc.internal-ip
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name        = aws_s3_bucket.scripts.id
  subnet             = aws_subnet.ws-subnet.id
  enable_public_ip   = var.enable_workstation_public_ip
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-icmp.id,
    aws_security_group.allow-ssh.id,
  ]

  instance_type     = var.centos_gfx_instance_type
  disk_size_gb      = var.centos_gfx_disk_size_gb

  ami_owner        = var.centos_gfx_ami_owner
  ami_product_code = var.centos_gfx_ami_product_code
  ami_name         = var.centos_gfx_ami_name

  admin_ssh_key_name = var.admin_ssh_key_name

  depends_on_hack = [aws_nat_gateway.nat.id]
}

module "centos-std" {
  source = "../../../modules/aws/centos-std"

  instance_count = var.centos_std_instance_count

  prefix = var.prefix

  customer_master_key_id = var.customer_master_key_id

  pcoip_registration_code = var.pcoip_registration_code

  domain_name                 = var.domain_name
  domain_controller_ip        = module.dc.internal-ip
  ad_service_account_username = var.ad_service_account_username
  ad_service_account_password = var.ad_service_account_password

  bucket_name        = aws_s3_bucket.scripts.id
  subnet             = aws_subnet.ws-subnet.id
  enable_public_ip   = var.enable_workstation_public_ip
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.allow-icmp.id,
    aws_security_group.allow-ssh.id,
  ]

  instance_type     = var.centos_std_instance_type
  disk_size_gb      = var.centos_std_disk_size_gb

  ami_owner        = var.centos_std_ami_owner
  ami_product_code = var.centos_std_ami_product_code
  ami_name         = var.centos_std_ami_name

  admin_ssh_key_name = var.admin_ssh_key_name

  depends_on_hack = [aws_nat_gateway.nat.id]
}
