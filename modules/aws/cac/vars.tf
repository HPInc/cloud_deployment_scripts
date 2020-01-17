/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "prefix" {
  description = "Prefix to add to name of new resources"
  default     = ""
}

variable "cam_url" {
  description = "Cloud Access Manager URL"
  default     = "https://cam.teradici.com"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type        = string
}

variable "cac_token" {
  description = "Connector Token from CAM Service"
  type        = string
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string
}

variable "domain_controller_ip" {
  description = "Internal IP of the Domain Controller"
  type        = string
}

variable "domain_group" {
  description = "Active Directory Distinguished Name for the User Group to log into the CAM Management Interface. Default is 'Domain Admins'. (eg, 'CN=CAM Admins,CN=Users,DC=example,DC=com')"
  default     = "Domain Admins"
}

variable "service_account_username" {
  description = "Active Directory Service Account username"
  type        = string
}

variable "service_account_password" {
  description = "Active Directory Service Account password"
  type        = string
}

variable "subnet" {
  description = "Subnet to deploy the Cloud Access Connector"
  type        = string
}

variable "security_group_ids" {
  description = "Security Groups to be applied to the Cloud Access Connector"
  type        = list(string)
}

variable "instance_count" {
  description = "Number of Cloud Access Connectors to deploy"
  default     = 1
}

variable "instance_type" {
  description = "Instance type for the Cloud Access Connector"
  default     = "t2.xlarge"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Cloud Access Connector"
  default     = "50"
}

variable "ami_owner" {
  description = "Owner of AMI for the Cloud Access Connector"
  default     = "099720109477"
}

variable "ami_name" {
  description = "Name of the AMI to create Cloud Access Connector from"
  default = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20191002"
}

variable "host_name" {
  description = "Name to give the host"
  default     = "vm-cac"
}

variable "admin_ssh_key_name" {
  description = "Name of Admin SSH Key"
  type        = string
}

variable "cac_installer_url" {
  description = "Location of the Cloud Access Connector installer"
  default     = "https://teradici.bintray.com/cloud-access-connector/cloud-access-connector-0.1.1.tar.gz"
}
