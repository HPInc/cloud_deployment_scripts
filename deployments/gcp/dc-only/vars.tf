/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "gcp_credentials_file" {
  description = "Location of GCP JSON credentials file"
  type = "string"
}

variable "gcp_project_id" {
  description = "GCP Project ID"
  type = "string"
}

variable "gcp_region" {
  description = "GCP region"
  default = "us-west2"
}
variable "gcp_zone" {
  description = "GCP zone"
  # Default to us-west2-b because P4 Workstation GPUs available here
  default = "us-west2-b"
}

variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 9 characters."
  default = ""
}

variable "dc_subnet_cidr" {
  description = "CIDR for subnet containing the Domain Controller"
  default = "10.0.0.0/24"
}

variable "dc_private_ip" {
  description = "Static internal IP address for the Domain Controller"
  default = "10.0.0.100"
}

variable "dc_machine_type" {
  description = "Machine type for Domain Controller"
  default = "n1-standard-2"
}

variable "dc_disk_image_project" {
  description = "Disk image project for Domain Controller"
  default = "windows-cloud"
}

variable "dc_disk_image_family" {
  description = "Disk image family for Domain Controller"
  default = "windows-2016"
}

variable "dc_disk_size_gb" {
  description = "Disk size (GB) of Domain Controller"
  default = 50
}

variable "dc_admin_password" {
  description = "Password for the Administrator of the Domain Controller"
  type = "string"
}

variable "domain_name" {
  description = "Domain name for the new domain"
  type = "string"
}

variable "safe_mode_admin_password" {
  description = "Safe Mode Admin Password (Directory Service Restore Mode - DSRM)"
  type = "string"
}

variable "service_account_username" {
  description = "Active Directory Service account name to be created"
  default = "cam_admin"
}

variable "service_account_password" {
  description = "Active Directory Service account password"
  type = "string"
}

variable "domain_users_list" {
  description = "Active Directory users to create, in CSV format"
  type = "string"
  default = ""
}

