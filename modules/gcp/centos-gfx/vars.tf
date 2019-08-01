/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "prefix" {
  description = "Prefix to add to name of new resources"
  default     = ""
}

variable "name" {
  description = "Basename of hostname of the workstation. Hostname will be <prefix>-<name>-<number>. Lower case only."
  default     = "gcent"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type        = string
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string
}

variable "domain_controller_ip" {
  description = "Internal IP of the Domain Controller"
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
  description = "Assign a public IP to the workstation"
  default     = false
}

variable "instance_count" {
  description = "Number of CentOS Graphics Workstations to deploy"
  default     = 1
}

variable "machine_type" {
  description = "Machine type for the Workstation"
  default     = "n1-standard-2"
}

variable "accelerator_type" {
  description = "Accelerator type for the Workstation"
  default     = "nvidia-tesla-p4-vws"
}

variable "accelerator_count" {
  description = "Number of GPUs for the Workstation"
  default     = "1"
}

variable "disk_image_project" {
  description = "Disk image project for the Workstation"
  default     = "centos-cloud"
}

#variable "disk_image_family" {
#  description = "Disk image family for the Workstation"
#  default = "centos-7"
#}
variable "disk_image" {
  description = "Disk image to use for the Workstation"
  default     = "centos-7-v20190619"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Workstation"
  default     = "50"
}

variable "ws_admin_user" {
  description = "Username of the Workstation Administrator"
  type        = string
}

variable "ws_admin_ssh_pub_key_file" {
  description = "SSH public key for the Workstation Administrator"
  type        = string
}

variable "depends_on_hack" {
  description = "Workaround for Terraform Modules not supporting depends_on"
  default     = []
}
