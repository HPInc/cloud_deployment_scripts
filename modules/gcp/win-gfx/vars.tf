/*
 * Copyright (c) 2019 Teradici Corporation
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

variable "gcp_zone" {
  description = "Zone to deploy the Cloud Access Connector"
  default     = "us-west2-b"
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
  description = "Number of Windows Graphics Workstations to deploy"
  default     = 1
}

variable "machine_type" {
  description = "Machine type for Workstation"
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
  default     = "windows-cloud"
}

#variable "disk_image_family" {
#  description = "Disk image family for the Workstation"
#  default = "windows-2016"
#}
variable "disk_image" {
  description = "Disk image to use for the Workstation"
  default     = "windows-server-2016-dc-v20190620"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Workstation"
  default     = "100"
}

variable "admin_password" {
  description = "Password for the Administrator of the Workstation"
  type        = string
}

variable "nvidia_driver_location" {
  description = "URL of NVIDIA GRID driver location"
  default     = "https://storage.googleapis.com/nvidia-drivers-us-public/GRID/GRID7.1/"
}

variable "nvidia_driver_filename" {
  description = "Filename of NVIDIA GRID driver"
  default     = "412.16_grid_win10_server2016_64bit_international.exe"
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
