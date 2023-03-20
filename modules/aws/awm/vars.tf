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

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Name of bucket to retrieve provisioning script."
  type        = string
}

variable "awm_deployment_sa_file" {
  description = "Filename of Anyware Manager Deployment Service Account JSON key in bucket"
  type        = string
}

variable "subnet" {
  description = "Subnet to deploy the Anyware Manager"
  type        = string
}

variable "enable_public_ip" {
  description = "Assign a public IP to Anyware Manager"
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "Security Groups to be applied to the Anyware Manager"
  type        = list(string)
}

variable "instance_type" {
  description = "Instance type for the Anyware Manager (min 4 GB RAM, 8 vCPUs)"
  default     = "t2.xlarge"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Anyware Manager (min 60 GB)"
  default     = "60"
}

variable "ami_owner" {
  description = "Owner of AMI for the Workstation"
  default     = "792107900819"
}

variable "ami_name" {
  description = "Name of the AMI to create Workstation from"
  default     = "Rocky-8-ec2*x86_64*"
}

variable "host_name" {
  description = "Name to give the host"
  default     = "vm-awm"
}

variable "admin_ssh_key_name" {
  description = "Name of Admin SSH Key"
  type        = string
}

variable "awm_aws_credentials_file" {
  description = "Name of AWS credentials file for Anyware Manager in bucket"
  type        = string
}

variable "awm_admin_password" {
  description = "Password for the Administrator of Anyware Manager"
  type        = string
  sensitive   = true
}

variable "teradici_download_token" {
  description = "Token used to download from Teradici"
  default     = "yj39yHtgj68Uv2Qf"
}

variable "awm_repo_channel" {
  description = "Anyware Manager repo in Anyware Manager repository channel"
  default     = "anyware-manager"
}

variable "customer_master_key_id" {
  description = "The ID of the AWS KMS Customer Master Key used to decrypt secrets"
  default     = ""
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
