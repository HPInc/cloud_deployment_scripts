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

resource "aws_secretsmanager_secret" "awm_deployment_sa_file" {
  name = "${var.prefix}awm_deployment_sa_file"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "awm_deployment_sa_file_value" {
  secret_id     = aws_secretsmanager_secret.awm_deployment_sa_file.id
  secret_string = file(var.awm_deployment_sa_file)
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
