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

variable "bucket_name" {
  description = "Name of bucket to retrieve startup script."
  type        = string
}

variable "subnet" {
  description = "Subnet to deploy the Workstation"
  type        = string
}

variable "security_group_ids" {
  description = "Security Groups to be applied to the PCoIP License Server"
  type        = list(string)
}

variable "instance_count" {
  description = "Number of PCoIP License Server to deploy"
  default     = 1
}

variable "instance_type" {
  description = "Instance type for the PCoIP License Server"
  default     = "t2.medium"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the PCoIP License Server"
  default     = "10"
}

variable "ami_owner" {
  description = "Owner of AMI for the PCoIP License Server"
  default     = "125523088429"
}

variable "ami_name" {
  description = "Name of the AMI to create PCoIP License Server from"
  default     = "CentOS 8*x86_64"
}

variable "host_name" {
  description = "Name to give the host"
  default     = "vm-lls"
}

variable "admin_ssh_key_name" {
  description = "Name of Admin SSH Key"
  type        = string
}

variable "lls_admin_password" {
  description = "Administrative password for the Teradici License Server"
  default     = ""
  sensitive   = true
}

variable "lls_activation_code" {
  description = "Activation Code for PCoIP session licenses"
  default     = ""
  sensitive   = true
}

variable "lls_license_count" {
  description = "Number of PCoIP session licenses to activate"
  default     = 0
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "customer_master_key_id" {
  description = "The ID of the AWS KMS Customer Master Key used to decrypt secrets"
  default     = ""
}

variable "cloudwatch_setup_script" {
  description = "The script that sets up the AWS CloudWatch Logs agent"
  type        = string
}
