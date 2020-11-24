/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

provider "google" {
  credentials = file(var.gcp_credentials_file)
  project     = local.gcp_project_id
  region      = var.gcp_region
  zone        = var.gcp_zone
}

provider "google-beta" {
  credentials = file(var.gcp_credentials_file)
  project     = local.gcp_project_id
  region      = var.gcp_region
  zone        = var.gcp_zone
}
