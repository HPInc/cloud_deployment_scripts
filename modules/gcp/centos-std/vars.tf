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

variable "name" {
  description = "Basename of hostname of the workstation. Hostname will be <prefix>-<name>-<number>. Lower case only."
  default     = "scent"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
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
  description = "Assign a public IP to the workstation"
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

variable "network_tags" {
  description = "Tags to be applied to the Workstation"
  type        = list(string)
}

variable "instance_count" {
  description = "Number of CentOS Standard Workstations to deploy"
  default     = 1
}

variable "machine_type" {
  description = "Machine type for the Workstation"
  default     = "n1-standard-2"
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
}

variable "pcoip_agent_repo_pubkey_url" {
  description = "URL of Teradici repo public key"
  default     = "https://downloads.teradici.com/rhel/teradici.pub.gpg"
}

variable "pcoip_agent_repo_url" {
  description = "URL of Teradici PCoIP Standard Agent"
  default     = "https://downloads.teradici.com/rhel/pcoip.repo"
}

variable "depends_on_hack" {
  description = "Workaround for Terraform Modules not supporting depends_on"
  default     = []
}

variable "kms_cryptokey_id" {
  description = "Resource ID of the KMS cryptographic key used to decrypt secrets, in the form of 'projects/<project-id>/locations/<location>/keyRings/<keyring-name>/cryptoKeys/<key-name>'"
  default     = ""
}
