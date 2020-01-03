/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "aws_credentials_file" {
    description = "Location of AWS credentails file"
    type        = string
}

variable "aws_region" {
  description = "AWS region"
  default     = "us-west-1"
}

variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 9 characters."
  default     = ""
}

variable "vpc_name" {
  description = "Name of VPC to create"
  default     = "vpc-cas"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC containing the CAS deployment"
  default     = "10.0.0.0/16" 
}

variable "dc_subnet_cidr" {
  description = "CIDR for subnet containing the Domain Controller"
  default     = "10.0.0.0/24"
}

variable "dc_private_ip" {
  description = "Static internal IP address for the Domain Controller"
  default     = "10.0.0.100"
}

variable "dc_instance_type" {
  description = "Instance type for the Domain Controller"
  default     = "t2.xlarge"
}

variable "dc_disk_size_gb" {
  description = "Disk size (GB) of the Domain Controller"
  default     = "50"
}

variable "dc_ami_owner" {
  description = "Owner of AMI for the Domain Controller"
  default     = "amazon"
}

variable "dc_ami_name" {
  description = "Name of the Windows AMI to create workstation from"
  default = "Windows_Server-2016-English-Full-Base-2019.11.13"
}

variable "domain_name" {
  description = "Domain name for the new domain"
  default     = "example.com"
}

variable "dc_admin_password" {
  description = "Password for the Administrator of the Domain Controller"
  type        = string
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

variable "cac_subnet_cidr" {
  description = "CIDR for subnet containing the Cloud Access Connector"
  default     = "10.0.1.0/24"
}

variable "cac_instance_count" {
  description = "Number of Cloud Access Connector instances"
  default     = 1
}

variable "cac_instance_type" {
  description = "Instance type for the Cloud Access Connector"
  default     = "t2.xlarge"
}

variable "cac_disk_size_gb" {
  description = "Disk size (GB) of the Cloud Access Connector"
  default     = "50"
}

variable "cac_ami_owner" {
  description = "Owner of AMI for the Cloud Access Connector"
  default     = "099720109477"
}

variable "cac_ami_name" {
  description = "Name of the AMI to create Cloud Access Connector from"
  default = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20191002"
}

variable "admin_ssh_key_name" {
  description = "Name of Admin SSH Key"
  default     = "cas_admin"
}

variable "admin_ssh_pub_key_file" {
  description = "Admin SSH public key file"
  type        = string
}

variable "cac_token" {
  description = "Connector Token from CAM Service"
  type        = string
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type        = string
}

variable "cam_url" {
  description = "cam server url."
  default     = "https://cam.teradici.com"
}

variable "ws_subnet_cidr" {
  description = "CIDR for subnet containing Remote Workstations"
  default     = "10.0.2.0/24"
}

variable "enable_workstation_public_ip" {
  description = "Enable public IP for Workstations"
  default     = false
}

variable "win_gfx_instance_count" {
  description = "Number of Windows Graphics Workstations"
  default     = 0
}

# G4s are Tesla T4s
# G3s are M60
variable "win_gfx_instance_type" {
  description = "Instance type for the Windows Graphics Workstations"
  default     = "g4dn.xlarge"
}

variable "win_gfx_disk_size_gb" {
  description = "Disk size (GB) of the Windows Graphics Workstations"
  default     = "50"
}

variable "win_gfx_ami_owner" {
  description = "Owner of AMI for the Windows Graphics Workstations"
  default     = "aws-marketplace"
}

variable "win_gfx_ami_name" {
  description = "Name of the Windows AMI to create workstation from"
  default     = "nvOffer-grid9.2-nv-windows-server-2016-QvWS-432.08-v201911180037*"
}

variable "win_std_instance_count" {
  description = "Number of Windows Standard Workstations"
  default     = 0
}

variable "win_std_instance_type" {
  description = "Instance type for the Windows Standard Workstations"
  default     = "t2.xlarge"
}

variable "win_std_disk_size_gb" {
  description = "Disk size (GB) of the Windows Standard Workstations"
  default     = "50"
}

variable "win_std_ami_owner" {
  description = "Owner of AMI for the Windows Standard Workstations"
  default     = "amazon"
}

variable "win_std_ami_name" {
  description = "Name of the Windows AMI to create workstation from"
  default     = "Windows_Server-2016-English-Full-Base-2019.11.13"
}

variable "centos_std_instance_count" {
  description = "Number of CentOS Standard Workstations"
  default     = 0
}

variable "centos_std_instance_type" {
  description = "Instance type for the CentOS Standard Workstations"
  default     = "t2.xlarge"
}

variable "centos_std_disk_size_gb" {
  description = "Disk size (GB) of the CentOS Standard Workstations"
  default     = "50"
}

variable "centos_std_ami_owner" {
  description = "Owner of AMI for the CentOS Standard Workstations"
  default     = "aws-marketplace"
}

variable "centos_std_ami_name" {
  description = "Name of the CentOS AMI to create workstation from"
  default     = "CentOS Linux 7 x86_64 HVM EBS ENA 1901*"
}
