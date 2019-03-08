variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 9 characters."
  default = ""
}
variable "subnet" {
  description = "Subnet to deploy the Workstation"
  type = "string"
}

variable "machine_type" {
  description = "Machine type for Workstation"
  default = "n1-standard-2"
}

variable "accelerator_type" {
  description = "Accelerator type for Workstation"
  default = "nvidia-tesla-p4-vws"
}

variable "disk_image_project" {
  description = "Disk image project for Workstation"
  default = "windows-cloud"
}

variable "disk_image_family" {
  description = "Disk image family for Workstation"
  default = "windows-2016"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of Workstation"
  default = "100"
}

variable "admin_password" {
  description = "Password for the Administrator of the Workstation"
  type = "string"
}