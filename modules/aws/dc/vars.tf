/*
 * Copyright Teradici Corporation 2020-2021;  © Copyright 2021-2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "prefix" {
  description = "Prefix to add to name of new resources"
  default     = ""
}

variable "domain_name" {
  description = "The name for the new domain"
  type        = string
}

variable "admin_password" {
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
  description = "Active Directory Service account to be created"
  type        = string
}

variable "ad_service_account_password" {
  description = "Active Directory Service account password"
  type        = string
  sensitive   = true
}

variable "domain_users_list" {
  description = "Active Directory users to create, in CSV format"
  default     = ""

  validation {
    condition = var.domain_users_list == "" ? true : fileexists(var.domain_users_list)
    error_message = "The domain_users_list file specified does not exist. Please check the file path."
  }
}

variable "bucket_name" {
  description = "Name of bucket to retrieve provisioning script."
  type        = string
}

variable "ldaps_cert_filename" {
  description = "Filename of Certificate used in LDAPS."
  type        = string
} 

variable "subnet" {
  description = "Subnet to deploy the Domain Controller"
  type        = string
}

variable "security_group_ids" {
  description = "Security Groups to be applied to the Domain Controller"
  type        = list(string)
}

variable "instance_type" {
  description = "Instance type for the Domain Controller"
  default     = "t2.xlarge"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Domain Controller"
  default     = "50"
}

variable "ami_owner" {
  description = "Owner of AMI"
  default     = "amazon"
}

variable "ami_name" {
  description = "Name of the Windows AMI to create the Domain Controller from"
  default     = "Windows_Server-2019-English-Full-Base-*"
}

variable "customer_master_key_id" {
  description = "The ID of the AWS KMS Customer Master Key used to decrypt secrets"
  default     = ""
}

variable "cloudwatch_setup_script" {
  description = "The script that sets up the AWS CloudWatch Logs agent"
  type        = string
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "pcoip_agent_version" {
  description = "PCoIP Agent version to install"
  default     = "latest"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code from Teradici"
  type        = string
  sensitive   = true
}

variable "cloudwatch_enable" {
  description = "Enable AWS CloudWatch Agent for sending logs to AWS CloudWatch"
  default     = true
}

variable "aws_ssm_enable" {
  description = "Enable AWS Session Manager integration for easier SSH/RDP admin access to EC2 instances"
  default     = true
}
