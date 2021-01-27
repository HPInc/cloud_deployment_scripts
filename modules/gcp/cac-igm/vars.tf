/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "gcp_service_account" {
  description = "Service Account in the GCP Project"
  type        = string
}

variable "prefix" {
  description = "Prefix to add to name of new resources"
  default     = ""
}

variable "cam_url" {
  description = "Cloud Access Manager URL (e.g. https://cam.teradici.com)"
  type        = string
}

variable "cam_insecure" {
  description = "Allow unverified SSL access to Cloud Access Manager"
  type        = bool
  default     = false
}

variable "cam_deployment_sa_file" {
  description = "Location of CAM Deployment Service Account JSON file"
  type        = string
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type        = string

  validation {
    condition     = can(regex("^[[:alnum:]]{12}@(?:[[:alnum:]]{4}-){3}[[:alnum:]]{4}$", var.pcoip_registration_code))
    error_message = "Invalid PCoIP Registration code. The format is expected to be xxxxxxxxxxxx@xxxx-xxxx-xxxx-xxxx."
  }
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string
}

variable "domain_controller_ip" {
  description = "Internal IP of the Domain Controller"
  type        = string
}

variable "domain_group" {
  description = "Active Directory Distinguished Name for the User Group to log into the CAM Management Interface. Default is 'Domain Admins'. (eg, 'CN=CAM Admins,CN=Users,DC=example,DC=com')"
  default     = "Domain Admins"
}

variable "ad_service_account_username" {
  description = "Active Directory Service Account username"
  type        = string
}

variable "ad_service_account_password" {
  description = "Active Directory Service Account password"
  type        = string
}

variable "bucket_name" {
  description = "Name of bucket to retrieve provisioning script."
  type        = string
}

variable "gcp_region_list" {
  description = "GCP regions to set up the Managed Instance Groups"
  type        = list(string)
}

variable "subnet_list" {
  description = "Subnets to deploy the Cloud Access Connector"
  type        = list(string)
}

variable "network_tags" {
  description = "Tags to be applied to the Cloud Access Connector"
  type        = list(string)
}

variable "instance_count_list" {
  description = "Number of Cloud Access Connector instances to deploy in each region"
  type        = list(number)
}

variable "host_name" {
  description = "Name to give the host"
  default     = "vm-cac"
}

variable "machine_type" {
  description = "Machine type for the Cloud Access Connector (min 4 GB RAM, 2 vCPUs)"
  default     = "n1-standard-2"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Cloud Access Connector (min 12 GB)"
  default     = "50"
}

variable "disk_image" {
  description = "Disk image for the Cloud Access Connector"
  default     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-1804-lts"
}

variable "cac_admin_user" {
  description = "Username of the Cloud Access Connector Administrator"
  type        = string
}

variable "cac_admin_ssh_pub_key_file" {
  description = "SSH public key for the Cloud Access Connector Administrator"
  type        = string
}

variable "cac_installer_url" {
  description = "Location of the Cloud Access Connector installer"
  default     = "https://dl.teradici.com/yj39yHtgj68Uv2Qf/cloud-access-connector/raw/names/cloud-access-connector-linux-tgz/versions/latest/cloud-access-connector_latest_Linux.tar.gz"
}

variable "external_pcoip_ip" {
  description = "External IP addresses to use to connect to the Cloud Access Connectors."
  default     = ""
}

variable "kms_cryptokey_id" {
  description = "Resource ID of the KMS cryptographic key used to decrypt secrets, in the form of 'projects/<project-id>/locations/<location>/keyRings/<keyring-name>/cryptoKeys/<key-name>'"
  default     = ""
}

variable "ssl_key" {
  description = "SSL private key for the Connector"
  default     = ""
}

variable "ssl_cert" {
  description = "SSL certificate for the Connector"
  default     = ""
}
