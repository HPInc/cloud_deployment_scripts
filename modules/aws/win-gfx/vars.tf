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

variable "name" {
  description = "Basename of hostname of the workstation. Hostname will be <prefix>-<name>-<number>. Lower case only."
  default     = "gwin"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code from Teradici"
  type        = string
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string
}

variable "service_account_username" {
  description = "Active Directory Service Account username"
  type        = string
}

variable "service_account_password" {
  description = "Active Directory Service Account password"
  type        = string
}

variable "bucket_name" {
  description = "Name of bucket to retrieve startup script."
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
  description = "Number of Windows Graphics Workstations to deploy"
  default     = 1
}

# G4s are Tesla T4s
# G3s are M60
variable "instance_type" {
  description = "Instance type for the Workstation"
  default     = "g4dn.xlarge"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Workstation"
  default     = "50"
}

variable "ami_owner" {
  description = "Owner of AMI"
  default     = "aws-marketplace"
}

variable "ami_name" {
  description = "Name of the Windows AMI to create workstation from"
  default     = "nvOffer-grid9.2-nv-windows-server-2016-QvWS-*"
}

variable "admin_password" {
  description = "Password for the Administrator of the Workstation"
  type        = string
}

variable "pcoip_agent_location" {
  description = "URL of Teradici PCoIP Graphics Agent"
  default     = "https://downloads.teradici.com/win/stable/"
}

variable "pcoip_agent_filename" {
  description = "Filename of Teradici PCoIP Graphics Agent. Leave blank to download the latest."
  default     = ""
}

variable "depends_on_hack" {
  description = "Workaround for Terraform Modules not supporting depends_on"
  default     = []
}
