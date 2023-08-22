/*
 * Copyright Teradici Corporation 2019-2021;  © Copyright 2022-2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  # Windows computer names must be <= 15 characters
  host_name                  = substr("${local.prefix}vm-dc", 0, 15)
  dc_sysprep_script          = "dc-sysprep.ps1"
  dc_provisioning_script     = "dc-provisioning.ps1"
  dc_new_ad_accounts_script  = "dc-new-ad-accounts.ps1"
  domain_users_list          = "domain_users_list.csv"
  #label value to check if the DC provisioning is successful or not
  final_status               = "dc-provisioning-completed"
  label_name                 = "provisioning_status"
  new_domain_users           = var.domain_users_list == "" ? 0 : 1
  # Directories start with "C:..." on Windows; All other OSs use "/" for root.
  is_windows_host            = substr(pathexpand("~"), 0, 1) == "/" ? false : true
}

resource "google_storage_bucket_object" "dc-sysprep-script" {
  bucket = var.bucket_name
  name   = local.dc_sysprep_script
  content = templatefile(
    "${path.module}/${local.dc_sysprep_script}.tmpl",
    {
      admin_password_id   = var.admin_password_id,
    }
  )
}

# NOTE:Avoid merging sysprep and provisioning scripts in GCP, 
# to prevent the occurrence of "Error Code: 19	Name change pending, 
# for AD Domain Services (AD DS),needs reboot". 

resource "google_storage_bucket_object" "dc-provisioning-script" {
  bucket = var.bucket_name
  name   = local.dc_provisioning_script
  content = templatefile(
    "${path.module}/${local.dc_provisioning_script}.tpl",
    {
      bucket_name                = var.bucket_name,
      domain_name                = var.domain_name,
      gcp_ops_agent_enable       = var.gcp_ops_agent_enable,
      ldaps_cert_filename        = var.ldaps_cert_filename,
      label_name                 = local.label_name
      ops_setup_script           = var.ops_setup_script,
      pcoip_agent_install        = var.pcoip_agent_install,
      pcoip_agent_version        = var.pcoip_agent_version,
      pcoip_registration_code_id    = var.pcoip_registration_code_id,
      safe_mode_admin_password_id   = var.safe_mode_admin_password_id,
      teradici_download_token    = var.teradici_download_token,
      dc_new_ad_accounts_script  = local.dc_new_ad_accounts_script,
    }
  )
}

resource "google_storage_bucket_object" "dc-new-ad-accounts-script" {
  bucket = var.bucket_name
  name   = local.dc_new_ad_accounts_script
  content = templatefile("${path.module}/${local.dc_new_ad_accounts_script}.tpl",
    {
      domain_name      = var.domain_name,
      account_name     = var.ad_service_account_username,
      account_password_id = var.ad_service_account_password_id,
      csv_file         = local.new_domain_users == 1 ? local.domain_users_list : "",
      bucket_name      = var.bucket_name,
      label_name       = local.label_name,
      final_status     = local.final_status,

    }
  )
}

resource "google_storage_bucket_object" "domain_users_list" {
  count   = local.new_domain_users == 1 ? 1 : 0

  bucket  = var.bucket_name
  name    = local.domain_users_list
  source  = var.domain_users_list
}

resource "google_compute_instance" "dc" {
  provider     = google
  name         = local.host_name
  zone         = var.gcp_zone
  machine_type = var.machine_type

  enable_display = true

  boot_disk {
    initialize_params {
      image = var.disk_image
      type  = "pd-ssd"
      size  = var.disk_size_gb
    }
  }

  network_interface {
  subnetwork = var.subnet
  network_ip = var.private_ip
}

  tags = var.network_tags

  metadata = {
    sysprep-specialize-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.dc-sysprep-script.output_name}"
    windows-startup-script-url    = "gs://${var.bucket_name}/${google_storage_bucket_object.dc-provisioning-script.output_name}"
  }

  service_account {
    email  = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}

resource "null_resource" "wait_for_DC_to_initialize_windows" {
  count = local.is_windows_host ? 1 : 0
  depends_on = [google_compute_instance.dc]
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = <<-EOT
      $labelValue = ""
      $startTime = Get-Date
      while ($labelValue -ne "${local.final_status}") {
          $labelValue = gcloud compute instances describe ${local.host_name} --zone ${var.gcp_zone} --format='value(labels.${local.label_name})'
          if ([string]::IsNullOrEmpty($labelValue)) {
              Write-Host "DC provisioning is starting"
          } else { 
              Write-Host "${local.label_name}:$labelValue"
          }
          $elapsedTime = New-TimeSpan -Start $startTime -End (Get-Date)
          if ($elapsedTime.TotalMinutes -ge 25) {
              Write-Host "Timeout Error: The DC provisioning process has taken longer than 25 minutes. The DC might be provisioned successfully, but please review CloudWatch Logs for any errors or consider destroying the deployment with 'terraform destroy' and redeploying using 'terraform apply'"
              break  # Exit the loop
          }
          Start-Sleep -Seconds 30
      }
    EOT
  }
}

resource "null_resource" "wait_for_DC_to_initialize_linux" {
  count = local.is_windows_host ? 0 : 1
  depends_on = [google_compute_instance.dc]
  provisioner "local-exec" {
    command = <<-EOT
      startTime=$(date +"%s")
      labelValue=""
      while [ "$labelValue" != "${local.final_status}" ]; do
          labelValue=$(gcloud compute instances describe "${local.host_name}" --zone "${var.gcp_zone}" --format="value(labels.${local.label_name})")

          if [ -z "$labelValue" ]; then
              echo "DC provisioning is starting"
          else
              echo "Provisioning Status: $labelValue"
          fi

          elapsedTime=$(( $(date +"%s") - startTime ))

          if [ "$elapsedTime" -ge 1500 ]; then
              echo "Timeout Error: The DC provisioning process has taken longer than 25 minutes. The DC might be provisioned successfully, but please review CloudWatch Logs for any errors or consider destroying the deployment with 'terraform destroy' and redeploying using 'terraform apply'"
              break
          fi
          sleep 30
        done
    EOT
  }
}
