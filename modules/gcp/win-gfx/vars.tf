/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "gcp_service_account" {
  description = "Service Account in the GCP Project"
  type        = string
}

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

variable "ad_service_account_username" {
  description = "Active Directory Service Account username"
  type        = string
}

variable "ad_service_account_password" {
  description = "Active Directory Service Account password"
  type        = string
}

variable "bucket_name" {
  description = "Name of bucket to retrieve startup script."
  type        = string
}

variable "gcp_zone" {
  description = "Zone to deploy the Workstation"
  default     = "us-west2-b"
}

variable "subnet" {
  description = "Subnet to deploy the Workstation"
  type        = string
}

variable "enable_public_ip" {
  description = "Assign a public IP to the Workstation"
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

variable "network_tags" {
  description = "Tags to be applied to the Workstation"
  type        = list(string)
}

variable "instance_count" {
  description = "Number of Windows Graphics Workstations to deploy"
  default     = 1
}

variable "machine_type" {
  description = "Machine type for Workstation"
  default     = "n1-standard-4"
}

variable "accelerator_type" {
  description = "Accelerator type for the Workstation"
  default     = "nvidia-tesla-p4-vws"
}

variable "accelerator_count" {
  description = "Number of GPUs for the Workstation"
  default     = "1"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Workstation"
  default     = "50"
}

variable "disk_image" {
  description = "Disk image for the Workstation"
  default     = "projects/windows-cloud/global/images/family/windows-2019"
}

variable "admin_password" {
  description = "Password for the Administrator of the Workstation"
  type        = string
}

variable "nvidia_driver_url" {
  description = "URL of NVIDIA GRID driver"
  default     = "https://storage.googleapis.com/nvidia-drivers-us-public/GRID/GRID9.1/431.79_grid_win10_server2016_server2019_64bit_international.exe"
}

variable "pcoip_agent_location_url" {
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

variable "kms_cryptokey_id" {
  description = "Resource ID of the KMS cryptographic key used to decrypt secrets, in the form of 'projects/<project-id>/locations/<location>/keyRings/<keyring-name>/cryptoKeys/<key-name>'"
  default     = ""
}
