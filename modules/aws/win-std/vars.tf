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

variable "instance_name" {
  description = "Basename of hostname of the workstation. Hostname will be <prefix>-<name>-<number>. Lower case only."
  default     = "swin"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code from Teradici"
  type        = string

  validation {
    # Allow empty string for using PCoIP License Server
    condition     = (var.pcoip_registration_code == "") || can(regex("^[[:alnum:]]{12}@(?:[[:alnum:]]{4}-){3}[[:alnum:]]{4}$", var.pcoip_registration_code))
    error_message = "Invalid PCoIP Registration code. The format is expected to be xxxxxxxxxxxx@xxxx-xxxx-xxxx-xxxx."
  }
}

variable "domain_name" {
  description = "Name of the domain to join"
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

variable "subnet" {
  description = "Subnet to deploy the Workstation"
  type        = string
}

variable "enable_public_ip" {
  description = "Assign a public IP to the Workstation"
  default     = false
}

variable "security_group_ids" {
  description = "Security Groups to be applied to the Workstation"
  type        = list(string)
}

variable "instance_count" {
  description = "Number of Windows Standard Workstations to deploy"
  default     = 1
}

variable "instance_type" {
  description = "Instance type for the Workstation"
  default     = "t2.xlarge"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Workstation"
  default     = "50"
}

variable "ami_owner" {
  description = "Owner of AMI"
  default     = "amazon"
}

variable "ami_name" {
  description = "Name of the Windows AMI to create workstation from"
  default     = "Windows_Server-2019-English-Full-Base-*"
}

variable "admin_password" {
  description = "Password for the Administrator of the Workstation"
  type        = string
}

variable "pcoip_agent_location_url" {
  description = "URL of Teradici PCoIP Standard Agent"
  default     = "https://downloads.teradici.com/win/stable/"
}

variable "pcoip_agent_filename" {
  description = "Filename of Teradici PCoIP Standard Agent. Leave blank to download the latest."
  default     = ""
}

variable "customer_master_key_id" {
  description = "The ID of the AWS KMS Customer Master Key used to decrypt secrets"
  default     = ""
}
