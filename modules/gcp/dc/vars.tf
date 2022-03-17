/*
 * Copyright Teradici Corporation 2021;  © Copyright 2021 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "gcp_service_account" {
  description = "Service Account in the GCP Project"
  type        = string
}

variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 9 characters."
  default     = ""
}

variable "domain_name" {
  description = "The name for the new domain"
  type        = string
}

variable "admin_password" {
  description = "Password for the Administrator of the Domain Controller"
  type        = string
  sensitive   = true
}

variable "safe_mode_admin_password" {
  description = "Safe Mode Admin Password (Directory Service Restore Mode - DSRM)"
  type        = string
  sensitive   = true
}

variable "ad_service_account_username" {
  description = "Active Directory Service account to be created"
  type        = string
}

variable "ad_service_account_password" {
  description = "Active Directory Service account password"
  type        = string
  sensitive   = true
}

variable "domain_users_list" {
  description = "Active Directory users to create, in CSV format"
  default     = ""
  
  validation {
    condition = var.domain_users_list == "" ? true : fileexists(var.domain_users_list)
    error_message = "The domain_users_list file specified does not exist. Please check the file path."
  }
}

variable "bucket_name" {
  description = "Name of bucket to retrieve provisioning script."
  type        = string
}

variable "gcp_zone" {
  description = "Zone to deploy the Domain Controller"
  default     = "us-west2-b"
}

variable "subnet" {
  description = "Subnet to deploy the Domain Controller"
  type        = string
}

variable "private_ip" {
  description = "Static internal IP address for the Domain Controller"
  type        = string
}

variable "network_tags" {
  description = "Tags to be applied to the Domain Controller"
  type        = list(string)
}

variable "machine_type" {
  description = "Machine type for the Domain Controller"
  default     = "n1-standard-4"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Domain Controller"
  default     = "50"
}

variable "disk_image" {
  description = "Disk image for the Domain Controller"
  default     = "projects/windows-cloud/global/images/family/windows-2019"
}

variable "kms_cryptokey_id" {
  description = "Resource ID of the KMS cryptographic key used to decrypt secrets, in the form of 'projects/<project-id>/locations/<location>/keyRings/<keyring-name>/cryptoKeys/<key-name>'"
  default     = ""
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "pcoip_agent_version" {
  description = "PCoIP Agent version to install"
  default     = "latest"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code from Teradici"
  type        = string
  sensitive   = true
}

variable "ops_setup_script" {
  description = "The script that sets up the GCP Ops Agent"
  type        = string
}

variable "gcp_ops_agent_enable" {
  description = "Enable GCP Ops Agent for sending logs to GCP"
  default     = true
}
