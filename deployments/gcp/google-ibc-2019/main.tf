/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  bucket_name = "${local.prefix}pcoip-scripts-${random_id.bucket-name.hex}"

  num_ws_vpcs = length(var.workstation_vpc_names)
  num_win_gfx = length(flatten([for i in var.win_gfx_instance_count: range(i)]))
  index_count_map = zipmap(range(local.num_ws_vpcs), var.win_gfx_instance_count)
  zone_list = flatten(
    [for idx, cnt in local.index_count_map:
      [for i in range(cnt):
        var.workstation_zones[idx]
      ]
    ]
  )
  subnet_list = flatten(
    [for idx, cnt in local.index_count_map:
      [for i in range(cnt):
        data.google_compute_subnetwork.subnet_workstations[idx].self_link
      ]
    ]
  )
  tags_list = chunklist(
    flatten(
      [for idx, cnt in local.index_count_map:
        [for i in range(cnt):
          [
            google_compute_firewall.allow-icmp-vpc-workstations[idx].name,
            google_compute_firewall.allow-rdp-vpc-workstations[idx].name,
          ]
        ]
      ]
    )
  ,2)
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

module "dc" {
  source = "../../../modules/gcp/dc"

  prefix = var.prefix

  gcp_service_account      = var.gcp_service_account
  kms_cryptokey_id         = var.kms_cryptokey_id
  domain_name              = var.domain_name
  admin_password           = var.dc_admin_password
  safe_mode_admin_password = var.safe_mode_admin_password
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password
  domain_users_list        = var.domain_users_list

  bucket_name = google_storage_bucket.scripts.name
  gcp_zone    = var.gcp_zone
  subnet      = google_compute_subnetwork.dc-subnet.self_link
  private_ip  = var.dc_private_ip

  machine_type       = var.dc_machine_type
  disk_size_gb       = var.dc_disk_size_gb

  network_tags = [
    "${google_compute_firewall.allow-dns-vpc-cam.name}",
    "${google_compute_firewall.allow-rdp-vpc-cam.name}",
    "${google_compute_firewall.allow-winrm-vpc-cam.name}",
    "${google_compute_firewall.allow-icmp-vpc-cam.name}",
  ]
}

module "cac" {
  source = "../../../modules/gcp/cac"

  prefix = var.prefix

  gcp_service_account     = var.gcp_service_account
  kms_cryptokey_id        = var.kms_cryptokey_id
  cam_url                 = var.cam_url
  pcoip_registration_code = var.pcoip_registration_code
  cac_token               = var.cac_token

  domain_name              = var.domain_name
  domain_controller_ip     = module.dc.internal-ip
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  bucket_name    = google_storage_bucket.scripts.name
  gcp_zone       = var.gcp_zone
  subnet         = google_compute_subnetwork.cac-subnet.self_link
  instance_count = var.cac_instance_count

  machine_type       = var.cac_machine_type
  disk_image_project = var.cac_disk_image_project
  disk_image_family  = var.cac_disk_image_family
  disk_size_gb       = var.cac_disk_size_gb

  network_tags = [
    "${google_compute_firewall.allow-ssh-vpc-cam.name}",
    "${google_compute_firewall.allow-icmp-vpc-cam.name}",
    "${google_compute_firewall.allow-http-vpc-cam.name}",
    "${google_compute_firewall.allow-https-vpc-cam.name}",
    "${google_compute_firewall.allow-pcoip-vpc-cam.name}",
  ]

  cac_admin_user              = var.cac_admin_user
  cac_admin_ssh_pub_key_file  = var.cac_admin_ssh_pub_key_file

  ssl_key  = var.ssl_key
  ssl_cert = var.ssl_cert
}

module "win-gfx" {
  source = "../../../modules/gcp/win-gfx"

  prefix = var.prefix

  gcp_service_account = var.gcp_service_account
  kms_cryptokey_id = var.kms_cryptokey_id

  pcoip_registration_code = var.pcoip_registration_code

  domain_name              = var.domain_name
  admin_password           = var.dc_admin_password
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  bucket_name      = google_storage_bucket.scripts.name
  gcp_zone_list    = local.zone_list
  subnet_list      = local.subnet_list
  enable_public_ip = var.enable_workstation_public_ip
  instance_count   = local.num_win_gfx

  machine_type      = var.win_gfx_machine_type
  accelerator_type  = var.win_gfx_accelerator_type
  accelerator_count = var.win_gfx_accelerator_count
  disk_size_gb      = var.win_gfx_disk_size_gb

  network_tags = local.tags_list

  disk_image_project = var.win_gfx_disk_image_project
  disk_image_family  = var.win_gfx_disk_image_family
  disk_image         = var.win_gfx_disk_image
}
