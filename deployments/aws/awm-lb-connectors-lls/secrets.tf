/*
 * Copyright 2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

resource "aws_secretsmanager_secret" "admin_password" {
  name = "${var.prefix}admin_password"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "admin_password_value" {
  secret_id     = aws_secretsmanager_secret.admin_password.id
  secret_string = var.dc_admin_password
}

resource "aws_secretsmanager_secret" "ad_service_account_password" {
  name = "${var.prefix}ad_service_account_password"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "ad_service_account_password_value" {
  secret_id     = aws_secretsmanager_secret.ad_service_account_password.id
  secret_string = var.ad_service_account_password
}

resource "aws_secretsmanager_secret" "awm_aws_credentials_file" {
  name = "${var.prefix}awm_aws_credentials_file"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "awm_aws_credentials_file_value" {
  secret_id     = aws_secretsmanager_secret.awm_aws_credentials_file.id
  secret_string = file(var.awm_aws_credentials_file)
}

# There's no secret version created for this secret.
# During the provisioning process, the DSA file will be uploaded by AWM.
resource "aws_secretsmanager_secret" "awm_deployment_sa_file" {
  name = "${var.prefix}awm_deployment_sa_file"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret" "lls_admin_password" {
  name = "${var.prefix}lls_admin_password"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "lls_admin_password_value" {
  secret_id     = aws_secretsmanager_secret.lls_admin_password.id
  secret_string = var.lls_admin_password
}

resource "aws_secretsmanager_secret" "lls_activation_code" {
  name = "${var.prefix}lls_activation_code"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "lls_activation_code_value" {
  secret_id     = aws_secretsmanager_secret.lls_activation_code.id
  secret_string = var.lls_activation_code
}

resource "aws_secretsmanager_secret" "pcoip_registration_code" {
  name = "${var.prefix}pcoip_registration_code"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "pcoip_registration_code_value" {
  secret_id     = aws_secretsmanager_secret.pcoip_registration_code.id
  secret_string = var.pcoip_registration_code
}

resource "aws_secretsmanager_secret" "safe_mode_admin_password" {
  name = "${var.prefix}safe_mode_admin_password"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "safe_mode_admin_password_value" {
  secret_id     = aws_secretsmanager_secret.safe_mode_admin_password.id
  secret_string = var.safe_mode_admin_password
}

# As The expected Input to LLS Deployments is a null value for PCOIP
# registration code.This secret serves as a placeholder to pass a
# null value for the PCOIP registration code to the workstation modules.
resource "aws_secretsmanager_secret" "dummy_secret" {
  name                    = "${var.prefix}dummy_secret"
  recovery_window_in_days = var.recovery_window_in_days
}
