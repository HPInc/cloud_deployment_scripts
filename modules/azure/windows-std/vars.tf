/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "resource_group_name" {
  description = "Basename of the Resource Group to deploy the workstation. Hostname will be <prefix>-<name>.Lower case only."
  type        = string
}

variable "admin_name" {
    description = "Name for the Administrator of the Workstation"
    type        = string
}

variable "admin_password" {
  description = "Password for the Administrator of the Workstation"
  type        = string
}

variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 9 characters."
  type        = string
}

variable "name" {
  description = "Basename of hostname of the workstation. Hostname will be <prefix>-<name>. Lower case only."
  type        = string
}

variable "pcoip_agent_location" {
  description = "URL of Teradici PCoIP Standard Agent"
  default     = "https://downloads.teradici.com/win/stable/"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code from Teradici"
  type        = string
}

variable "azure_region" {
  description = "Region to dpeloy the workstation"
  type        = string
  default     = "centralus"
}

variable "ad_service_account_password" {
  description = "Active Directory Service Account password"
  type        = string
}

variable "ad_service_account_username" {
  description = "Active Directory Service Account username"
  type        = string
}

variable "public_ip_allocation" {
  description = "Public IP Allocation Method. Dynamic or Static."
  type        = string
  default     = "Static"
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Vnet to deploy the agent"
  type        = string
}

variable "vnet_rg_name" {
  description = "Name of the resource group of the Vnet"
  type        = string
}

variable "vm_size" {
    description = "Size of the VM to deploy"
    type        = string
    default     = "Standard_B2ms"
}

variable "_artifactsLocation" {
    description = "URL to retrieve startup scripts with a trailing /"
    type        = string
}

variable "_artifactsLocationSasToken" {
    description = "Sas Token of the URL is optional, only if required for security reasons"
    type        = string
}