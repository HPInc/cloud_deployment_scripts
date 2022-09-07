/*
 * Copyright Teradici Corporation 2020-2022;  © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "gcp_credentials_file" {
  description = "Location of GCP Service Account key file to be used by Terraform"
  type        = string

  validation {
    condition = fileexists(var.gcp_credentials_file)
    error_message = "The gcp_credentials_file specified does not exist. Please check the file path."
  }
}

variable "gcp_region" {
  description = "GCP region"
  default     = "us-west2"
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

variable "allowed_client_cidrs" {
  description = "Open VPC firewall to allow PCoIP connections from these IP Addresses or CIDR ranges. e.g. ['a.b.c.d', 'e.f.g.0/24']"
  default     = ["0.0.0.0/0"]
}

variable "vpc_name" {
  description = "Name for VPC containing the Cloud Access Software deployment"
  default     = "vpc-cas"
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
  default     = "projects/windows-cloud/global/images/windows-server-2019-dc-v20220902"
}

variable "dc_admin_password" {
  description = "Password for the Administrator of the Domain Controller"
  type        = string
  sensitive   = true
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
      length(regexall("([.]local$)",var.domain_name)) == 0 &&
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
  default     = "cas_ad_admin"
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
    condition = var.domain_users_list == "" ? true : fileexists(var.domain_users_list)
    error_message = "The domain_users_list file specified does not exist. Please check the file path."
  }
}

variable "cas_mgr_subnet_name" {
  description = "Name for subnet containing the CAS Manager"
  default     = "subnet-cas-mgr"
}

variable "cas_mgr_subnet_cidr" {
  description = "CIDR for subnet containing the CAS Manager"
  default     = "10.0.0.16/28"
}

variable "cas_mgr_machine_type" {
  description = "Machine type for CAS Manager"
  default     = "e2-standard-4"
}

variable "cas_mgr_disk_size_gb" {
  description = "Disk size (GB) of CAS Manager"
  default     = 60
}

variable "cas_mgr_disk_image" {
  description = "Disk image for the CAS Manager"
  default     = "projects/rocky-linux-cloud/global/images/rocky-linux-8-v20220822"
}

variable "cas_mgr_admin_user" {
  description = "Username of CAS Manager Administrator (SSH)"
  default     = "cas_admin"
}

variable "cas_mgr_admin_ssh_pub_key_file" {
  description = "SSH public key for CAS Manager Administrator"
  type        = string

  validation {
    condition = fileexists(var.cas_mgr_admin_ssh_pub_key_file)
    error_message = "The cas_mgr_admin_ssh_pub_key_file specified does not exist. Please check the file path."
  }
}

variable "cas_mgr_admin_password" {
  description = "Password for the Administrator of CAS Manager"
  type        = string
  sensitive   = true
}

variable "cas_mgr_gcp_credentials_file" {
  description = "Location of GCP Service Account key file to be used by CAS Manager"
  type        = string

  validation {
    condition = fileexists(var.cas_mgr_gcp_credentials_file)
    error_message = "The cas_mgr_gcp_credentials_file specified does not exist. Please check the file path."
  }
}

variable "cac_region_list" {
  description = "Regions in which to deploy Connectors"
  type        = list(string)
}

variable "cac_subnet_name" {
  description = "Name for subnets containing the Cloud Access Connector"
  default     = "subnet-cac"
}

variable "cac_subnet_cidr_list" {
  description = "CIDRs for subnets containing the Cloud Access Connector"
  type        = list(string)
}

variable "cac_instance_count_list" {
  description = "Number of Cloud Access Connector instances to deploy in each region"
  type        = list(number)
}

variable "cac_machine_type" {
  description = "Machine type for Cloud Access Connector"
  default     = "n1-standard-2"
}

variable "cac_disk_size_gb" {
  description = "Disk size (GB) of Cloud Access Connector"
  default     = 50
}

variable "cac_disk_image" {
  description = "Disk image for the Cloud Access Connector"
  default     = "projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20220901"
}

# TODO: does this have to match the tag at the end of the SSH pub key?
variable "cac_admin_user" {
  description = "Username of Cloud Access Connector Administrator"
  default     = "cas_admin"
}

variable "cac_admin_ssh_pub_key_file" {
  description = "SSH public key for Cloud Access Connector Administrator"
  type        = string

  validation {
    condition = fileexists(var.cac_admin_ssh_pub_key_file)
    error_message = "The cac_admin_ssh_pub_key_file specified does not exist. Please check the file path."
  }
}

variable "cac_ssl_key" {
  description = "SSL private key for the Connector in PEM format"
  default     = ""

  validation {
    condition = var.cac_ssl_key == "" ? true : fileexists(var.cac_ssl_key)
    error_message = "The cac_ssl_key file specified does not exist. Please check the file path."
  }
}

variable "cac_ssl_cert" {
  description = "SSL certificate for the Connector in PEM format"
  default     = ""

  validation {
    condition = var.cac_ssl_cert == "" ? true : fileexists(var.cac_ssl_cert)
    error_message = "The cac_ssl_cert file specified does not exist. Please check the file path."
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

variable "cac_enable_external_ip" {
  description = "Enable external IP address assignments for each Connector. For testing/debugging purposes only"
  default     = false
}

variable "ws_region_list" {
  description = "Regions in which to deploy Workstations"
  type        = list(string)
}

variable "ws_zone_list" {
  description = "Zones in which to deploy Workstations"
  type        = list(string)
}

variable "ws_subnet_name" {
  description = "Name for subnet containing Remote Workstations"
  default     = "subnet-ws"
}

variable "ws_subnet_cidr_list" {
  description = "CIDR for subnets containing Remote Workstations"
  type        = list(string)
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

variable "enable_workstation_public_ip" {
  description = "Enable public IP for Workstations"
  default     = false
}

variable "auto_logoff_enable" {
  description = "Enable auto log-off for Workstations"
  default     = true
}

variable "auto_logoff_minutes_idle_before_logoff" {
  description = "Minimum idle time for Workstations before auto log-off, must be between 5 and 10000"
  default     = 20
}

variable "auto_logoff_polling_interval_minutes" {
  description = "Polling interval for checking CPU utilization to determine if machine is idle, must be between 1 and 100"
  default     = 5
}

variable "auto_logoff_cpu_utilization" {
  description = "CPU utilization percentage, must be between 1 and 100"
  default     = 20
}

variable "idle_shutdown_enable" {
  description = "Enable auto idle shutdown for Workstations"
  default     = true
}

variable "idle_shutdown_minutes_idle_before_shutdown" {
  description = "Minimum idle time for Workstations before auto idle shutdown, must be between 5 and 10000"
  default     = 240
}

variable "idle_shutdown_polling_interval_minutes" {
  description = "Polling interval for checking CPU utilization to determine if machine is idle, must be between 1 and 60"
  default     = 15
}

variable "idle_shutdown_cpu_utilization" {
  description = "CPU utilization percentage, must be between 1 and 100"
  default     = 20
}

variable "win_gfx_instance_count_list" {
  description = "Number of Windows Graphics Workstations to deploy in each region"
  type        = list(number)
}

variable "win_gfx_instance_name" {
  description = "Name for Windows Graphics Workstations"
  default     = "gwin"
}

variable "win_gfx_machine_type" {
  description = "Machine type for Windows Graphics Workstations"
  default     = "n1-standard-4"
}

variable "win_gfx_accelerator_type" {
  description = "Accelerator type for Windows Graphics Workstations"
  default     = "nvidia-tesla-p4-vws"
}

variable "win_gfx_accelerator_count" {
  description = "Number of GPUs for Windows Graphics Workstations"
  default     = 1
}

variable "win_gfx_disk_size_gb" {
  description = "Disk size (GB) of Windows Graphics Workstations"
  default     = 50
}

variable "win_gfx_disk_image" {
  description = "Disk image for the Windows Graphics Workstation"
  default     = "projects/windows-cloud/global/images/windows-server-2019-dc-v20220902"
}

variable "win_gfx_pcoip_agent_version" {
  description = "Version of PCoIP Agent to install for Windows Graphics Workstations"
  default     = "latest"
}

variable "win_std_instance_count_list" {
  description = "Number of Windows Standard Workstations to deploy in each region"
  type        = list(number)
}

variable "win_std_instance_name" {
  description = "Name for Windows Standard Workstations"
  default     = "swin"
}

variable "win_std_machine_type" {
  description = "Machine type for Windows Standard Workstations"
  default     = "n1-standard-4"
}

variable "win_std_disk_size_gb" {
  description = "Disk size (GB) of Windows Standard Workstations"
  default     = 50
}

variable "win_std_disk_image" {
  description = "Disk image for the Windows Standard Workstation"
  default     = "projects/windows-cloud/global/images/windows-server-2019-dc-v20220902"
}

variable "win_std_pcoip_agent_version" {
  description = "Version of PCoIP Agent to install for Windows Standard Workstations"
  default     = "latest"
}

variable "centos_gfx_instance_count_list" {
  description = "Number of CentOS Graphics Workstations to deploy in each region"
  type        = list(number)
}

variable "centos_gfx_instance_name" {
  description = "Name for CentOS Graphics Workstations"
  default     = "gcent"
}

variable "centos_gfx_machine_type" {
  description = "Machine type for CentOS Graphics Workstations"
  default     = "n1-standard-2"
}

variable "centos_gfx_accelerator_type" {
  description = "Accelerator type for CentOS Graphics Workstations"
  default     = "nvidia-tesla-p4-vws"
}

variable "centos_gfx_accelerator_count" {
  description = "Number of GPUs for CentOS Graphics Workstations"
  default     = 1
}

variable "centos_gfx_disk_size_gb" {
  description = "Disk size (GB) of CentOS Graphics Workstations"
  default     = 50
}

variable "centos_gfx_disk_image" {
  description = "Disk image for the CentOS Graphics Workstation"
  default     = "projects/centos-cloud/global/images/centos-7-v20220822"
}

variable "centos_std_instance_count_list" {
  description = "Number of CentOS Standard Workstations to deploy in each region"
  type        = list(number)
}

variable "centos_std_instance_name" {
  description = "Name for CentOS Standard Workstations"
  default     = "scent"
}

variable "centos_std_machine_type" {
  description = "Machine type for CentOS Standard Workstations"
  default     = "n1-standard-2"
}

variable "centos_std_disk_size_gb" {
  description = "Disk size (GB) of CentOS Standard Workstations"
  default     = 50
}

variable "centos_std_disk_image" {
  description = "Disk image for the CentOS Standard Workstation"
  default     = "projects/centos-cloud/global/images/centos-7-v20220822"
}

variable "centos_admin_user" {
  description = "Username of CentOS Workstations"
  default     = "cas_admin"
}

variable "centos_admin_ssh_pub_key_file" {
  description = "SSH public key for CentOS Workstation Administrator"
  type        = string

  validation {
    condition = fileexists(var.centos_admin_ssh_pub_key_file)
    error_message = "The centos_admin_ssh_pub_key_file specified does not exist. Please check the file path."
  }
}

variable "kms_cryptokey_id" {
  description = "Resource ID of the KMS cryptographic key used to decrypt secrets"
  default     = ""
}

variable "gcp_ops_agent_enable" {
  description = "Enable GCP Ops Agent for sending logs to GCP"
  default     = true
}

variable "gcp_iap_enable" {
  description = "Enable GCP IAP for connecting instances via IAP"
  default     = true
}

variable "gcp_logging_retention_days" {
  description = "Retention period for created logging storage bucket"
  default     = 30
}
