/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "resource_group_name" {
  description = "Basename of the Resource Group to deploy the workstation. Hostname will be <prefix>-<name>.Lower case only."
  type        = "string"
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

variable "public_ip_allocation" {
  description = "Public IP Allocation Method. Dynamic or Static."
  type        = string
  default     = "Static"
}

variable "vm_size" {
  description = "Size of the VM to deploy"
  type        = string
  default     = "Standard_B2ms"
}

variable "application_id" {
  description = "The application (client) ID of your app registration in AAD"
  type        = string
}

variable "aad_client_secret" {
  description = "The client secret of your app registration in AAD"
  type        = string
}

variable "tenant_id" {
  description = "The directory (tenant) ID of your app registration in AAD"
  type        = string
}

variable "key_identifier" {
  description = "The key identifier in your azure key vault, follow this format https://<keyvault-name>.vault.azure.net/keys/<key-name>/<key-version>"
  type        = string
}

variable "ad_service_account_password" {
  description = "Active Directory Service Account password"
  type        = string
}

variable "ad_service_account_username" {
  description = "Active Directory Service Account username"
  type        = string
}

variable "domain_controller_ip" {
  description = "Internal IP of the Domain Controller"
  type        = string
}

variable "domain_name" {
  description = "Name of the domain to join"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the storage account to store boot diagnostic logs"
  type        = string
}

variable "storage_account_rg" {
  description = "Name of the resource group of the storage account to store boot diagnostic logs"
  type        = string
}

variable "_artifactsLocation" {
    description = "URL to retrieve startup scripts with a trailing /"
    type        = string
}

variable "_artifactsLocationSasToken" {
    description = "Sas Token of the URL is optional, only if required for security reasons"
    type        = string
}