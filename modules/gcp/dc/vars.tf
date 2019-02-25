variable "prefix" {
  description = "Prefix to add to name of new resources"
  default = ""
}
variable "subnet" {
  description = "Subnet to deploy Domain Controller"
  type = "string"
}

variable "private_ip" {
  description = "Static internal IP address for the Domain Controller"
  default = ""
}

variable "machine_type" {
  description = "Machine type for Domain Controller"
  default = "n1-standard-2"
}

variable "disk_image_project" {
  description = "Disk image project for Domain Controller"
  default = "windows-cloud"
}

variable "disk_image_family" {
  description = "Disk image family for Domain Controller"
  default = "windows-2016"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of Domain Controller"
  default = "50" 
}

variable "admin_password" {
  description = "Password for the Administrator of the Domain Controller"
  type = "string"
}

variable "domain_name" {
  description = "Domain name for the new domain"
  type = "string"
}

variable "safe_mode_admin_password" {
  description = "Safe Mode Admin Password (Directory Service Restore Mode - DSRM)"
  type = "string"
}

variable "service_account_name" {
  description = "Service account name to be created"
  type = "string"
}

variable "service_account_password" {
  description = "Service account password"
  type = "string"
}
