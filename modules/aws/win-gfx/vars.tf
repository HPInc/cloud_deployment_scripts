/*
 * Copyright Teradici Corporation 2020-2022;  © Copyright 2022-2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "aws_region" {
  description = "AWS region"
  default     = "us-west-1"
}

variable "prefix" {
  description = "Prefix to add to name of new resources"
  default     = ""
}

variable "instance_name" {
  description = "Basename of hostname of the workstation. Hostname will be <prefix>-<name>-<number>. Lower case only."
  default     = "gwin"
}

variable "pcoip_registration_code_id" {
  description = "Secrets Manager ARN for PCoIP Registration code from Teradici"
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

variable "ad_service_account_username" {
  description = "Active Directory Service Account username"
  type        = string
}

variable "ad_service_account_password_id" {
  description = "Secrets Manager ARN for Active Directory Service Account password"
  type        = string
  sensitive   = true
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
  default     = "amazon"
}

variable "ami_name" {
  description = "Name of the Windows AMI to create workstation from"
  default     = "Windows_Server-2019-English-Full-Base-*"
}

variable "admin_password_id" {
  description = "Secrets Manager ARN for Password of the Administrator of the Workstation"
  type        = string
}

variable "nvidia_driver_url" {
  description = "URL of NVIDIA GRID driver"
  default     = "https://s3.amazonaws.com/ec2-windows-nvidia-drivers/grid-14.1/"
}

variable "nvidia_driver_filename" {
  description = "Filename of NVIDIA GRID driver"
  default     = "512.78_grid_win10_win11_server2016_server2019_server2022_64bit_AWS_SWL.exe"
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "pcoip_agent_version" {
  description = "PCoIP Agent version to install"
  default     = "latest"
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

variable "cloudwatch_setup_script" {
  description = "The script that sets up the AWS CloudWatch Logs agent"
  type        = string
}

variable "cloudwatch_enable" {
  description = "Enable AWS CloudWatch Agent for sending logs to AWS CloudWatch"
  default     = true
}

variable "aws_ssm_enable" {
  description = "Enable AWS Session Manager integration for easier SSH/RDP admin access to EC2 instances"
  default     = true
}
