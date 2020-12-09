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

variable "gcp_region" {
  description = "GCP region"
  default     = "us-west2"
}

variable "gcp_zone" {
  description = "GCP zone"

  # Default to us-west2-b because Tesla P4 Workstation GPUs available here
  default = "us-west2-b"
}

variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 9 characters."
  default     = ""
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
  default     = "projects/windows-cloud/global/images/windows-server-2019-dc-v20201110"
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

variable "ad_service_account_username" {
  description = "Active Directory Service account name to be created"
  default     = "cam_admin"
}

variable "ad_service_account_password" {
  description = "Active Directory Service account password"
  type        = string
}

variable "domain_users_list" {
  description = "Active Directory users to create, in CSV format"
  type        = string
  default     = ""
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
  default     = "projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20201201"
}

# TODO: does this have to match the tag at the end of the SSH pub key?
variable "cac_admin_user" {
  description = "Username of Cloud Access Connector Administrator"
  default     = "cam_admin"
}

variable "cac_admin_ssh_pub_key_file" {
  description = "SSH public key for Cloud Access Connector Administrator"
  type        = string
}

variable "cac_health_check" {
  description = "Health check configuration for Cloud Access Connector"
  default = {
    path         = "/pcoip-broker/xml"
    port         = 443
    interval_sec = 5
    timeout_sec  = 5
  }
}

variable "glb_ssl_key" {
  description = "SSL private key for the Global Load Balancer in PEM format"
  default     = ""
}

variable "glb_ssl_cert" {
  description = "SSL certificate for the Global Load Balancer in PEM format"
  default     = ""
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

variable "cam_url" {
  description = "cam server url."
  default     = "https://cam.teradici.com"
}

variable "cam_deployment_sa_file" {
  description = "Location of CAM Deployment Service Account account JSON file"
  type        = string
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type        = string
}

variable "enable_workstation_public_ip" {
  description = "Enable public IP for Workstations"
  default     = false
}

variable "enable_workstation_idle_shutdown" {
  description = "Enable Cloud Access Manager auto idle shutdown for Workstations"
  default     = true
}

variable "minutes_idle_before_shutdown" {
  description = "Minimum idle time for Workstations before auto idle shutdown, must be between 5 and 10000"
  default     = 240
}

variable "minutes_cpu_polling_interval" {
  description = "Polling interval for checking CPU utilization to determine if machine is idle, must be between 1 and 60"
  default     = 15
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
  default     = "projects/windows-cloud/global/images/windows-server-2019-dc-v20201110"
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
  default     = "projects/windows-cloud/global/images/windows-server-2019-dc-v20201110"
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
  default     = "projects/centos-cloud/global/images/centos-7-v20201112"
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
  default     = "projects/centos-cloud/global/images/centos-7-v20201112"
}

variable "centos_admin_user" {
  description = "Username of CentOS Workstations"
  default     = "cam_admin"
}

variable "centos_admin_ssh_pub_key_file" {
  description = "SSH public key for CentOS Workstation Administrator"
  type        = string
}

variable "kms_cryptokey_id" {
  description = "Resource ID of the KMS cryptographic key used to decrypt secrets"
  default     = ""
}
