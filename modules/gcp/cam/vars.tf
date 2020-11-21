/*
 * Copyright (c) 2020 Teradici Corporation
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

variable "gcp_sa_file" {
  description = "Filename of GCP Service Account JSON key in bucket (Optional)"
  default     = ""
}

variable "gcp_region" {
  description = "GCP Region to deploy the Cloud Access Managers"
  type        = string
}

variable "gcp_zone" {
  description = "GCP Zone to deploy the Cloud Access Managers"
  type        = string
}

variable "subnet" {
  description = "Subnet to deploy the Cloud Access Managers"
  type        = string
}

variable "enable_public_ip" {
  description = "Assign a public IP to Cloud Access Manager"
  type        = bool
  default     = true
}

variable "network_tags" {
  description = "Tags to be applied to the Cloud Access Manager"
  type        = list(string)
}

variable "host_name" {
  description = "Name to give the host"
  default     = "vm-cam"
}

variable "machine_type" {
  description = "Machine type for the Cloud Access Manager (min 8 GB RAM, 4 CPUs)"
  default     = "e2-custom-4-8192"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Cloud Access Manager (min 60 GB)"
  default     = "60"
}

variable "disk_image" {
  description = "Disk image for the Cloud Access Manager"
  default     = "projects/centos-cloud/global/images/family/centos-8"
}

variable "cam_admin_user" {
  description = "Username of the Cloud Access Manager Administrator"
  type        = string
}

variable "cam_admin_ssh_pub_key_file" {
  description = "SSH public key for the Cloud Access Manager Administrator"
  type        = string
}

variable "cam_gui_admin_password" {
  description = "Password for the Administrator of Cloud Access Manager"
  type        = string
}

variable "cam_add_repo_script" {
  description = "Location of script to add repo for Cloud Access Manager"
  default     = "https://dl.teradici.com/yj39yHtgj68Uv2Qf/cloud-access-manager-dev/cfg/setup/bash.rpm.sh"
}
