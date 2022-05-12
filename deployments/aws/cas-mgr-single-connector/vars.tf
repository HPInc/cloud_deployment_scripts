/*
 * Copyright Teradici Corporation 2020-2021;  © Copyright 2021-2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "aws_credentials_file" {
    description = "Location of AWS credentials file"
    type        = string

    validation {
      condition = fileexists(var.aws_credentials_file)
      error_message = "The aws_credentials_file specified does not exist. Please check the file path."
    }
}

variable "aws_region" {
  description = "AWS region"
  default     = "us-west-1"
}

variable "keypair_name" {
  description = "AWS Keypair used to SSH onto EC2 instances"
  default     = ""
}

variable "cas_mgr_aws_credentials_string" {
  description = "String version of the aws credentials file"
  default     = ""
}

# "usw2-az4" failed to provision t2.xlarge EC2 instances in April 2020
# "use1-az3" failed to provision g4dn.xlarge Windows EC2 instances in April 2020
variable "az_id_exclude_list" {
  description = "List of Availability Zone IDs to exclude."
  default     = ["usw2-az4", "use1-az3"]
}

variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 9 characters."
  default     = ""
}

variable "allowed_admin_cidrs" {
  description = "Open VPC firewall to allow ICMP, SSH, WinRM and RDP from these IP Addresses or CIDR ranges. e.g. ['a.b.c.d/32', 'e.f.g.0/24']"
  default     = []
}

variable "allowed_client_cidrs" {
  description = "Open VPC firewall to allow PCoIP connections from these IP Addresses or CIDR ranges. e.g. ['a.b.c.d/32', 'e.f.g.0/24']"
  default     = ["0.0.0.0/0"]
}

variable "admin_ssh_key_name" {
  description = "Name of Admin SSH Key"
  default     = "cas_admin"
}

variable "admin_ssh_pub_key_file" {
  description = "Admin SSH public key file"
  type        = string

  validation {
    condition = fileexists(var.admin_ssh_pub_key_file)
    error_message = "The admin_ssh_pub_key_file specified does not exist. Please check the file path."
  }
}

variable "vpc_name" {
  description = "Name for VPC containing the CAS deployment"
  default     = "vpc-cas"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC containing the CAS deployment"
  default     = "10.0.0.0/16" 
}

variable "dc_subnet_name" {
  description = "Name for subnet containing the Domain Controller"
  default     = "subnet-dc"
}

variable "dc_subnet_cidr" {
  description = "CIDR for subnet containing the Domain Controller"
  default     = "10.0.0.0/28"
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
  default     = "Windows_Server-2019-English-Full-Base-2022.04.13"
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

variable "dc_admin_password" {
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

variable "cas_mgr_instance_type" {
  description = "Instance type for the CAS Manager"
  default     = "t2.xlarge"
}

variable "cas_mgr_disk_size_gb" {
  description = "Disk size (GB) of the CAS Manager"
  default     = "60"
}

variable "cas_mgr_ami_owner" {
  description = "Owner of AMI for the CAS Manager"
  default     = "792107900819"
}

variable "cas_mgr_ami_name" {
  description = "Name of the AMI to create CAS Manager from"
  default     = "Rocky-8-ec2-8.5-20211114.2.x86_64"
}

variable "cas_mgr_admin_password" {
  description = "Password for the Administrator of CAS Manager"
  type        = string
  sensitive   = true
}

variable "cas_mgr_aws_credentials_file" {
    description = "Location of AWS credentials file for CAS Manager"
    type        = string

    validation {
      condition = fileexists(var.cas_mgr_aws_credentials_file)
      error_message = "The cas_mgr_aws_credentials_file specified does not exist. Please check the file path."
    }
}

variable "cas_connector_subnet_name" {
  description = "Name for subnet containing the CAS Connector"
  default     = "subnet-cas-connector"
}

variable "cas_connector_subnet_cidr" {
  description = "CIDR for subnet containing the CAS Connector"
  default     = "10.0.1.0/24"
}

variable "cas_connector_instance_count" {
  description = "Number of CAS Connector instances"
  default     = 1
}

variable "cas_connector_instance_type" {
  description = "Instance type for the CAS Connector"
  default     = "t2.xlarge"
}

variable "cas_connector_disk_size_gb" {
  description = "Disk size (GB) of the CAS Connector"
  default     = "60"
}

variable "cas_connector_ami_owner" {
  description = "Owner of AMI for the CAS Connector"
  default     = "792107900819"
}

variable "cas_connector_ami_name" {
  description = "Name of the AMI to create CAS Connector from"
  default     = "Rocky-8-ec2-8.5-20211114.2.x86_64"
}

variable "tls_key" {
  description = "TLS private key for the Connector"
  default     = ""

  validation {
    condition = var.tls_key == "" ? true : fileexists(var.tls_key)
    error_message = "The tls_key file specified does not exist. Please check the file path."
  }
}

variable "tls_cert" {
  description = "TLS certificate for the Connector"
  default     = ""

  validation {
    condition = var.tls_cert == "" ? true : fileexists(var.tls_cert)
    error_message = "The tls_cert file specified does not exist. Please check the file path."
  }
}

variable "cas_connector_extra_install_flags" {
  description = "Additional flags for installing CAS Connector"
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

variable "ws_subnet_name" {
  description = "Name for subnet containing Remote Workstations"
  default     = "subnet-ws"
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

variable "win_gfx_instance_name" {
  description = "Name for Windows Graphics Workstations"
  default     = "gwin"
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
  default     = "amazon"
}

variable "win_gfx_ami_name" {
  description = "Name of the Windows AMI to create workstation from"
  default     = "Windows_Server-2019-English-Full-Base-2022.04.13"
}

variable "win_gfx_pcoip_agent_version" {
  description = "Version of PCoIP Agent to install for Windows Graphics Workstations"
  default     = "latest"
}

variable "win_std_instance_count" {
  description = "Number of Windows Standard Workstations"
  default     = 0
}

variable "win_std_instance_name" {
  description = "Name for Windows Standard Workstations"
  default     = "swin"
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
  default     = "Windows_Server-2019-English-Full-Base-2022.04.13"
}

variable "win_std_pcoip_agent_version" {
  description = "Version of PCoIP Agent to install for Windows Standard Workstations"
  default     = "latest"
}

variable "centos_gfx_instance_count" {
  description = "Number of CentOS Graphics Workstations"
  default     = 0
}

variable "centos_gfx_instance_name" {
  description = "Name for CentOS Graphics Workstations"
  default     = "gcent"
}

# G4s are Tesla T4s
# G3s are M60
variable "centos_gfx_instance_type" {
  description = "Instance type for the CentOS Graphics Workstations"
  default     = "g4dn.xlarge"
}

variable "centos_gfx_disk_size_gb" {
  description = "Disk size (GB) of the CentOS Graphics Workstations"
  default     = "50"
}

variable "centos_gfx_ami_owner" {
  description = "Owner of AMI for the CentOS Graphics Workstations"
  default     = "125523088429"
}

variable "centos_gfx_ami_name" {
  description = "Name of the CentOS AMI to create workstation from"
  default     = "CentOS 7.9.2009 x86_64"
}

variable "centos_std_instance_count" {
  description = "Number of CentOS Standard Workstations"
  default     = 0
}

variable "centos_std_instance_name" {
  description = "Name for CentOS Standard Workstations"
  default     = "scent"
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
  default     = "125523088429"
}

variable "centos_std_ami_name" {
  description = "Name of the CentOS AMI to create workstation from"
  default     = "CentOS 7.9.2009 x86_64"
}

variable "customer_master_key_id" {
  description = "The ID of the AWS KMS Customer Master Key used to decrypt secrets"
  default     = ""
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

variable "cloudwatch_enable" {
  description = "Enable AWS CloudWatch Agent for sending logs to AWS CloudWatch"
  default     = true
}

variable "aws_ssm_enable" {
  description = "Enable AWS Session Manager integration for easier SSH/RDP admin access to EC2 instances"
  default     = true
}

###########
# Accept networking defined upstream
###########
variable "vpc_id" {
  description = ""
  type        = string
}

variable "public_subnet_ids" {
  description = ""
  type        = list
}

variable "private_subnet_ids" {
  description = ""
  type        = list
}

