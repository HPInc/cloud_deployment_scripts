/*
 * © Copyright 2024 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

resource "google_secret_manager_secret" "dc_admin_password" {
  secret_id = "${var.prefix}_dc_admin_password"

  // Automatic replication policy allows GCP to choose the best region to replicate 
  // secret payload, which allows high availability.
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "dc_admin_password_value" {
  secret = google_secret_manager_secret.dc_admin_password.id
  secret_data = var.dc_admin_password
}

resource "google_secret_manager_secret" "safe_mode_admin_password" {
  secret_id = "${var.prefix}_safe_mode_admin_password"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "safe_mode_admin_password_value" {
  secret = google_secret_manager_secret.safe_mode_admin_password.id
  secret_data = var.safe_mode_admin_password
}

resource "google_secret_manager_secret" "ad_service_account_password" {
  secret_id = "${var.prefix}_ad_service_account_password"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "ad_service_account_password_value" {
  secret = google_secret_manager_secret.ad_service_account_password.id
  secret_data = var.ad_service_account_password
}

resource "google_secret_manager_secret" "pcoip_registration_code" {
  secret_id = "${var.prefix}_pcoip_registration_code"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "pcoip_registration_code_value" {
  secret = google_secret_manager_secret.pcoip_registration_code.id
  secret_data = var.pcoip_registration_code
}

# There's no secret version created for this secret.
# During the provisioning process, the DSA file will be uploaded by AWM.
resource "google_secret_manager_secret" "awm_deployment_sa_file" {
  secret_id = "${var.prefix}_awm_deployment_sa_file"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "awm_admin_password" {
  secret_id = "${var.prefix}_awm_admin_password"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "awm_admin_password_value" {
  secret = google_secret_manager_secret.awm_admin_password.id
  secret_data = var.awm_admin_password
}

resource "google_secret_manager_secret" "awm_gcp_credentials_file" {
  secret_id = "${var.prefix}_awm_gcp_credentials_file"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "awm_gcp_credentials_file_value" {
  secret = google_secret_manager_secret.awm_gcp_credentials_file.id

  # Encoded to base64 to accommodate potential change of the credentials file to binary or other non-JSON format
  secret_data = filebase64(var.awm_gcp_credentials_file)
}