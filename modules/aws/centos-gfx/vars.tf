/*
 * Copyright (c) 2020 Teradici Corporation
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
  default     = "gcent"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type        = string
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string

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
}

variable "bucket_name" {
  description = "Name of bucket to retrieve provisioning script."
  type        = string
}

variable "subnet" {
  description = "Subnet to deploy the Workstation"
  type        = string
}

variable "security_group_ids" {
  description = "Security Groups to be applied to the Workstation"
  type        = list(string)
}

variable "enable_public_ip" {
  description = "Assign a public IP to the workstation"
  default     = false
}

variable "instance_count" {
  description = "Number of CentOS Graphics Workstations to deploy"
  default     = 1
}

variable "instance_type" {
  description = "Instance type for the Workstation"
  default     = "g4dn.xlarge"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Workstation"
  default     = "50"
}

variable "ami_owner" {
  description = "Owner of AMI for the Workstation"
  default     = "125523088429"
}

variable "ami_name" {
  description = "Name of the AMI to create Workstation from"
  default     = "CentOS 7*x86_64"
}

variable "admin_ssh_key_name" {
  description = "Name of Admin SSH Key"
  type        = string
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "nvidia_driver_url" {
  description = "URL of NVIDIA GRID driver"
  default     = "https://s3.amazonaws.com/ec2-linux-nvidia-drivers/grid-12.0/NVIDIA-Linux-x86_64-460.32.03-grid-aws.run"
}

variable "customer_master_key_id" {
  description = "The ID of the AWS KMS Customer Master Key used to decrypt secrets"
  default     = ""
}
