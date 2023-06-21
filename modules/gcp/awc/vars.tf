/*
 * © Copyright 2022 HP Development Company, L.P.
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

variable "manager_url" {
  description = "Anyware Manager URL (e.g. https://cas.teradici.com)"
  type        = string
}

variable "awc_flag_manager_insecure" {
  description = "AWC install flag that allows unverified TLS access to Anyware Manager"
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
      length(regexall("([.]local$)", var.domain_name)) == 0 &&
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
  sensitive   = true
}

variable "ldaps_cert_filename" {
  description = "Filename of Certificate used in LDAPS."
  type        = string
}

variable "computers_dn" {
  description = "Base DN to search for computers within Active Directory."
  type        = string
}

variable "users_dn" {
  description = "Base DN to search for users within Active Directory."
  type        = string
}

variable "bucket_name" {
  description = "Name of bucket to retrieve provisioning script."
  type        = string
}

variable "awm_deployment_sa_file" {
  description = "Filename of Anyware Manager Deployment Service Account JSON key in bucket"
  type        = string
}

variable "gcp_region_list" {
  description = "GCP Regions to deploy the Anyware Connectors"
  type        = list(string)
}

variable "subnet_list" {
  description = "Subnets to deploy the Anyware Connectors"
  type        = list(string)
}

variable "external_pcoip_ip_list" {
  description = "List of external IP addresses to use to connect to the Anyware Connectors, one per region"
  default     = []
}

variable "enable_awc_external_ip" {
  description = "Enable external IP address assignment to each Connector"
  default     = false
}

variable "network_tags" {
  description = "Tags to be applied to the Anyware Connector"
  type        = list(string)
}

variable "instance_count_list" {
  description = "Number of Anyware Connector instances to deploy in each zone"
  type        = list(number)
}

variable "host_name" {
  description = "Name to give the host"
  default     = "vm-awc"
}

variable "machine_type" {
  description = "Machine type for the Anyware Connector"
  default     = "n1-standard-2"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Anyware Connector"
  default     = "60"
}

variable "disk_image" {
  description = "Disk image for the Anyware Connector"
  default     = "projects/rocky-linux-cloud/global/images/family/rocky-linux-8"
}

variable "awc_admin_user" {
  description = "Username of the Anyware Connector Administrator"
  type        = string
}

variable "awc_admin_ssh_pub_key_file" {
  description = "SSH public key for the Anyware Connector Administrator"
  type        = string

  validation {
    condition     = fileexists(var.awc_admin_ssh_pub_key_file)
    error_message = "The awc_admin_ssh_pub_key_file specified does not exist. Please check the file path."
  }
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "tls_key" {
  description = "TLS private key for the Connector"
  default     = ""

  validation {
    condition     = var.tls_key == "" ? true : fileexists(var.tls_key)
    error_message = "The tls_key file specified does not exist. Please check the file path."
  }
}

variable "tls_cert" {
  description = "TLS certificate for the Connector"
  default     = ""

  validation {
    condition     = var.tls_cert == "" ? true : fileexists(var.tls_cert)
    error_message = "The tls_cert file specified does not exist. Please check the file path."
  }
}

variable "awc_extra_install_flags" {
  description = "Additional flags for installing AWC"
  default     = ""
}

variable "kms_cryptokey_id" {
  description = "Resource ID of the KMS cryptographic key used to decrypt secrets, in the form of 'projects/<project-id>/locations/<location>/keyRings/<keyring-name>/cryptoKeys/<key-name>'"
  default     = ""
}

variable "ops_setup_script" {
  description = "The script that sets up the GCP OPs agent"
  type        = string
}

variable "gcp_ops_agent_enable" {
  description = "Enable GCP Ops Agent for sending logs to GCP"
  default     = true
}