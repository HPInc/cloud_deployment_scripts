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
  default     = "aws-marketplace"
}

variable "ami_product_code" {
  description = "Product Code of the AMI for the Workstation"
  default     = "aw0evgkw8e5c1q413zgy5pjce"
}

variable "ami_name" {
  description = "Name of the AMI to create Workstation from"
  default     = "CentOS Linux 7 x86_64 HVM EBS ENA 2002*"
}

variable "host_name" {
  description = "Name to give the host"
  default     = "vm-lls"
}

variable "admin_ssh_key_name" {
  description = "Name of Admin SSH Key"
  type        = string
}

variable "lls_repo_url" {
  description = "Location of the Teradici License Server RPM repo"
  default     = "https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm"
}

variable "lls_admin_password" {
  description = "Administrative password for the Teradici License Server"
  default     = ""
}

variable "lls_activation_code" {
  description = "Activation Code for PCoIP session licenses"
  default     = ""
}

variable "lls_license_count" {
  description = "Number of PCoIP session licenses to activate"
  default     = 0
}

variable "depends_on_hack" {
  description = "Workaround for Terraform Modules not supporting depends_on"
  default     = []
}

variable "customer_master_key_id" {
  description = "The ID of the AWS KMS Customer Master Key used to decrypt secrets"
  default     = ""
}
