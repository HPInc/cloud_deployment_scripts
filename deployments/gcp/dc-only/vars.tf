/*
 * Copyright Teradici Corporation 2019-2021;  © Copyright 2021 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "gcp_credentials_file" {
  description = "Location of GCP JSON credentials file"
  type        = string

  validation {
    condition     = fileexists(var.gcp_credentials_file)
    error_message = "The gcp_credentials_file specified does not exist. Please check the file path."
  }
}

variable "gcp_region" {
  description = "GCP region"
  default     = "us-west2"
}

variable "enable_icmp" {
  description = "Flag to enable or disable the compute firewall for ICMP protocol on all workstations from allowed_admin_cidrs"
  type        = bool
  default     = false
}

variable "enable_rdp" {
  description = "Flag to enable or disable the compute firewall on TCP/UDP 3389 Port on all Windows-based machines from allowed_admin_cidrs"
  type        = bool
  default     = false
}
variable "gcp_zone" {
  description = "GCP zone"

  # Default to us-west2-b because Tesla P4 Workstation GPUs available here
  default = "us-west2-b"
}

# NetBIOS name is limited to 15 characters. 10 characters are reserved for workstation type
# and number of instance. e.g. -scent-999. So the max length for prefix is 5 characters. 
variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 5 characters."
  default     = ""

  validation {
    condition     = length(var.prefix) <= 5
    error_message = "Prefix should have a maximum of 5 characters."
  }
}

variable "allowed_admin_cidrs" {
  description = "Open VPC firewall to allow ICMP, SSH, WinRM and RDP from these IP Addresses or CIDR ranges. e.g. ['a.b.c.d', 'e.f.g.0/24']"
  default     = []
}

variable "vpc_name" {
  description = "Name for VPC containing the HP Anyware deployment"
  default     = "vpc-anyware"
}

variable "dc_subnet_name" {
  description = "Name for subnet containing the Domain Controller"
  default     = "subnet-dc"
}

variable "dc_subnet_cidr" {
  description = "CIDR for subnet containing the Domain Controller"
  default     = "10.0.0.0/28"
}

variable "dc_private_ip" {
  description = "Static internal IP address for the Domain Controller"
  default     = "10.0.0.10"
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
  default     = "projects/windows-cloud/global/images/windows-server-2019-dc-v20231213"
}

variable "dc_admin_password" {
  description = "Password for the Administrator of the Domain Controller"
  type        = string
  sensitive   = true
}

variable "dc_pcoip_agent_install" {
  description = "Install PCoIP agent on Domain Controller"
  default     = false
}

variable "dc_pcoip_agent_version" {
  description = "Version of PCoIP Agent to install for Domain Controller"
  default     = "latest"
}

variable "domain_name" {
  description = "Domain name for the new domain"
  default     = "example.com"

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

variable "safe_mode_admin_password" {
  description = "Safe Mode Admin Password (Directory Service Restore Mode - DSRM)"
  type        = string
  sensitive   = true
}

variable "ad_service_account_username" {
  description = "Active Directory Service account name to be created"
  default     = "anyware_ad_admin"
}

variable "ad_service_account_password" {
  description = "Active Directory Service account password"
  type        = string
  sensitive   = true
}

variable "domain_users_list" {
  description = "Active Directory users to create, in CSV format"
  type        = string
  default     = ""

  validation {
    condition     = var.domain_users_list == "" ? true : fileexists(var.domain_users_list)
    error_message = "The domain_users_list file specified does not exist. Please check the file path."
  }
}

variable "kms_cryptokey_id" {
  description = "Resource ID of the KMS cryptographic key used to decrypt secrets"
  default     = ""
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type        = string
  sensitive   = true
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "allowed_client_cidrs" {
  description = "Open VPC firewall to allow PCoIP connections from these IP Addresses or CIDR ranges. e.g. ['a.b.c.d', 'e.f.g.0/24']"
  default     = ["0.0.0.0/0"]
}

variable "gcp_ops_agent_enable" {
  description = "Enable GCP Ops Agent for sending logs to GCP"
  default     = true
}

variable "gcp_iap_enable" {
  description = "Enables or Disables Access via GCP's IAP: If set to 'true', this option opens TCP ports 22 (SSH) and 3389 (RDP) in the compute firewall, specifically for traffic originating from GCP's IAP CIDR range. This allows administrators to access VMs using SSH or RDP through GCP's IAP TCP forwarding feature"
  type        = bool
  default     = true
}

variable "gcp_logging_retention_days" {
  description = "Retention period for created logging storage bucket"
  default     = 30
}
