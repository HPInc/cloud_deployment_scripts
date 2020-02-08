/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 9 characters."
  default     = ""
}

variable "domain_name" {
  description = "The name for the new domain"
  type        = string
}

variable "admin_password" {
  description = "Password for the Administrator of the Domain Controller"
  type        = string
}

variable "safe_mode_admin_password" {
  description = "Safe Mode Admin Password (Directory Service Restore Mode - DSRM)"
  type        = string
}

variable "service_account_username" {
  description = "Active Directory Service account to be created"
  type        = string
}

variable "service_account_password" {
  description = "Active Directory Service account password"
  type        = string
}

variable "domain_users_list" {
  description = "Active Directory users to create, in CSV format"
  default     = ""
}

variable "bucket_name" {
  description = "Name of bucket to retrieve startup script."
  type        = string
}

variable "subnet" {
  description = "Subnet to deploy the Domain Controller"
  type        = string
}

variable "private_ip" {
  description = "Static internal IP address for the Domain Controller"
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
  default     = "Windows_Server-2016-English-Full-Base-*"
}
