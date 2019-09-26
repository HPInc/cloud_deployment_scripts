/*
 * Copyright (c) 2019 Teradici Corporation
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

  bucket_name  = google_storage_bucket.scripts.name
  gcp_zone     = var.gcp_zone
  subnet       = google_compute_subnetwork.dc-subnet.self_link
  private_ip   = var.dc_private_ip
  network_tags = [
    "${google_compute_firewall.allow-dns.name}",
    "${google_compute_firewall.allow-rdp.name}",
    "${google_compute_firewall.allow-winrm.name}",
    "${google_compute_firewall.allow-icmp.name}",
  ]

  machine_type = var.dc_machine_type
  disk_size_gb = var.dc_disk_size_gb

  disk_image = var.dc_disk_image
}
