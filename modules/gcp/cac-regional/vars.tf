/*
 * Copyright (c) 2020 Teradici Corporation
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

variable "cas_mgr_url" {
  description = "CAS Manager URL (e.g. https://cas.teradici.com)"
  type        = string
}

variable "cas_mgr_insecure" {
  description = "Allow unverified SSL access to CAS Manager"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string

  /* validation notes:
      - the name is at least 2 levels and at most 3, as we have only tested up to 3 levels
  */
  validation {
    condition = (
      length(regexall("([.]local$)",var.domain_name)) == 0 &&
      length(var.domain_name) < 256 &&
      can(regex(
        "(^[A-Za-z0-9][A-Za-z0-9-]{0,13}[A-Za-z0-9][.])([A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9][.]){0,1}([A-Za-z]{2,}$)", 
        var.domain_name))
    )
    error_message = "Domain name is invalid. Please try again."
  }
}

variable "domain_controller_ip" {
  description = "Internal IP of the Domain Controller"
  type        = string
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

variable "cas_mgr_deployment_sa_file" {
  description = "Filename of CAS Manager Deployment Service Account JSON key in bucket"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region to deploy the Cloud Access Connectors"
  type        = string
}

variable "subnet" {
  description = "Subnet to deploy the Cloud Access Connectors"
  type        = string
}

variable "external_pcoip_ip" {
  description = "External IP addresses to use to connect to the Cloud Access Connectors."
  default     = ""
}

variable "enable_cac_external_ip" {
  description = "Enable external IP address assignment to each Connector"
  default     = false
}

variable "network_tags" {
  description = "Tags to be applied to the Cloud Access Connector"
  type        = list(string)
}

variable "instance_count" {
  description = "Number of Cloud Access Connector instances to deploy"
  default     = 1
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

  validation {
    condition = fileexists(var.cac_admin_ssh_pub_key_file)
    error_message = "The cac_admin_ssh_pub_key_file specified does not exist. Please check the file path."
  }
}

variable "cac_extra_install_flags" {
  description = "Additional flags for installing CAC"
  default     = ""
}

variable "cac_version" {
  description = "Version of the Cloud Access Connector to install"
  default     = "latest"
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "kms_cryptokey_id" {
  description = "Resource ID of the KMS cryptographic key used to decrypt secrets, in the form of 'projects/<project-id>/locations/<location>/keyRings/<keyring-name>/cryptoKeys/<key-name>'"
  default     = ""
}

variable "cas_mgr_script" {
  description = "Name of script to interact with CAS Manager"
  type        = string
}

variable "ssl_key_filename" {
  description = "SSL private key for the Connector"
  type        = string
}

variable "ssl_cert_filename" {
  description = "SSL certificate for the Connector"
  type        = string
}
