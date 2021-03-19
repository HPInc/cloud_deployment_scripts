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

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type        = string
}

variable "bucket_name" {
  description = "Name of bucket to retrieve provisioning script."
  type        = string
}

variable "cam_deployment_sa_file" {
  description = "Filename of CAM Deployment Service Account JSON key in bucket"
  type        = string
}

variable "subnet" {
  description = "Subnet to deploy the Cloud Access Manager"
  type        = string
}

variable "enable_public_ip" {
  description = "Assign a public IP to Cloud Access Manager"
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "Security Groups to be applied to the Cloud Access Manager"
  type        = list(string)
}

variable "instance_type" {
  description = "Instance type for the Cloud Access Manager (min 4 GB RAM, 8 vCPUs)"
  default     = "t2.xlarge"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Cloud Access Manager (min 60 GB)"
  default     = "60"
}

variable "ami_owner" {
  description = "Owner of AMI for the Cloud Access Manager"
  default     = "aws-marketplace"
}

variable "ami_product_code" {
  description = "Product Code of the AMI for the Cloud Access Manager"
  default     = "47k9ia2igxpcce2bzo8u3kj03"
}

variable "host_name" {
  description = "Name to give the host"
  default     = "vm-cam"
}

variable "admin_ssh_key_name" {
  description = "Name of Admin SSH Key"
  type        = string
}

variable "cam_aws_credentials_file" {
    description = "Name of AWS credentials file for Cloud Access Manager in bucket"
    type        = string
}

variable "cam_gui_admin_password" {
  description = "Password for the Administrator of Cloud Access Manager"
  type        = string
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "customer_master_key_id" {
  description = "The ID of the AWS KMS Customer Master Key used to decrypt secrets"
  default     = ""
}
