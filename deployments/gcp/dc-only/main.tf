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
