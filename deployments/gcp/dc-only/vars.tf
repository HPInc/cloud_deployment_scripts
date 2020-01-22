/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "gcp_credentials_file" {
  description = "Location of GCP JSON credentials file"
  type        = string
}

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_service_account" {
  description = "Service Account in the GCP Project"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  default     = "us-west1"
}

variable "gcp_zone" {
  description = "GCP zone"

  # Default to us-west1-b because Tesla T4 Workstation GPUs available here
  default = "us-west1-b"
}

variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 9 characters."
  default     = ""
}

variable "allowed_cidr" {
  description = "Open VPC firewall to allow ICMP, SSH, WinRM and RDP from these IP Addresses or CIDR ranges. e.g. ['a.b.c.d', 'e.f.g.0/24']"
  default     = []
}

variable "vpc_name" {
  description = "Name of VPC to create"
  default     = "vpc-cas"
}

variable "dc_subnet_cidr" {
  description = "CIDR for subnet containing the Domain Controller"
  default     = "10.0.0.0/24"
}

variable "dc_private_ip" {
  description = "Static internal IP address for the Domain Controller"
  default     = "10.0.0.100"
}

variable "dc_machine_type" {
  description = "Machine type for Domain Controller"
  default     = "n1-standard-4"
}

variable "dc_disk_size_gb" {
  description = "Disk size (GB) of Domain Controller"
  default     = 50
}

variable "dc_disk_image" {
  description = "Disk image for the Domain Controller"
  default     = "projects/windows-cloud/global/images/windows-server-2016-dc-v20200114"
}

variable "dc_admin_password" {
  description = "Password for the Administrator of the Domain Controller"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the new domain"
  default     = "example.com"
}

variable "safe_mode_admin_password" {
  description = "Safe Mode Admin Password (Directory Service Restore Mode - DSRM)"
  type        = string
}

variable "service_account_username" {
  description = "Active Directory Service account name to be created"
  default     = "cam_admin"
}

variable "service_account_password" {
  description = "Active Directory Service account password"
  type        = string
}

variable "domain_users_list" {
  description = "Active Directory users to create, in CSV format"
  type        = string
  default     = ""
}

variable "kms_cryptokey_id" {
  description = "Resource ID of the KMS cryptographic key used to decrypt secrets"
  default     = ""
}
