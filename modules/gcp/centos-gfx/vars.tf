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
  description = "Prefix to add to name of new resources"
  default     = ""
}

variable "instance_name" {
  description = "Basename of hostname of the workstation. Hostname will be <prefix>-<name>-<number>. Lower case only."
  default     = "gcent"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string

  /* validation notes:
      - the name is at least 2 levels and at most 3, as we have only tested up to 3 levels
  */
  validation {
    condition = (
      length(regexall("([.]local$)", var.domain_name)) == 0 &&
      length(var.domain_name) < 256 &&
      can(regex(
        "(^[A-Za-z0-9][A-Za-z0-9-]{0,13}[A-Za-z0-9][.])([A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9][.]){0,1}([A-Za-z]{2,}$)",
      var.domain_name))
    )
    error_message = "Domain name is invalid. Please try again."
  }
}

variable "domain_controller_ip" {
  description = "Internal IP of the Domain Controller"
  type        = string
}

variable "ad_service_account_username" {
  description = "Active Directory Service Account username"
  type        = string
}

variable "ad_service_account_password" {
  description = "Active Directory Service Account password"
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Name of bucket to retrieve provisioning script."
  type        = string
}

variable "zone_list" {
  description = "GCP zones to deploy the Workstations"
  type        = list(string)
}

variable "subnet_list" {
  description = "Subnets to deploy the Workstations"
  type        = list(string)
}

variable "enable_public_ip" {
  description = "Assign a public IP to the workstation"
  default     = false
}

variable "auto_logoff_enable" {
  description = "Enable auto log-off for Workstations"
  default     = true
}

variable "auto_logoff_minutes_idle_before_logoff" {
  description = "Minimum idle time for Workstations before auto log-off, must be between 5 and 10000"
  default     = 20
}

variable "auto_logoff_polling_interval_minutes" {
  description = "Polling interval for checking CPU utilization to determine if machine is idle, must be between 1 and 100"
  default     = 5
}

variable "auto_logoff_cpu_utilization" {
  description = "CPU utilization percentage, must be between 1 and 100"
  default     = 20
}

variable "idle_shutdown_enable" {
  description = "Enable Anyware Manager auto idle shutdown for Workstations"
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

variable "idle_shutdown_cpu_utilization" {
  description = "CPU utilization percentage, must be between 1 and 100"
  default     = 20
}

variable "network_tags" {
  description = "Tags to be applied to the Workstation"
  type        = list(string)
}

variable "instance_count_list" {
  description = "Number of Workstations to deploy in each zone"
  type        = list(number)
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

variable "disk_size_gb" {
  description = "Disk size (GB) of the Workstation"
  default     = "50"
}

variable "disk_image" {
  description = "Disk image for the Workstation"
  default     = "projects/centos-cloud/global/images/family/centos-7"
}

variable "ws_admin_user" {
  description = "Username of the Workstation Administrator"
  type        = string
}

variable "ws_admin_ssh_pub_key_file" {
  description = "SSH public key for the Workstation Administrator"
  type        = string

  validation {
    condition     = fileexists(var.ws_admin_ssh_pub_key_file)
    error_message = "The ws_admin_ssh_pub_key_file specified does not exist. Please check the file path."
  }
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "nvidia_driver_url" {
  description = "URL of NVIDIA GRID driver"
  default     = "https://storage.googleapis.com/nvidia-drivers-us-public/GRID/GRID13.1/NVIDIA-Linux-x86_64-470.82.01-grid.run"
}

variable "ops_setup_script" {
  description = "The script that sets up the GCP Ops Agent"
  type        = string
}

variable "gcp_ops_agent_enable" {
  description = "Enable GCP Ops Agent for sending logs to GCP"
  default     = true
}
