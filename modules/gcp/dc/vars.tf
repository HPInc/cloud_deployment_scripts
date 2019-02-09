variable "dc_subnet" {
  description = "Subnet to deploy Domain Controller"
  type = "string"
}

variable "dc_machine_type" {
  description = "Machine type for Domain Controller"
  default = "n1-standard-2"
}

variable "dc_disk_image_project" {
  description = "Disk image project for Domain Controller"
  default = "windows-cloud"
}

variable "dc_disk_image_family" {
  description = "Disk image family for Domain Controller"
  default = "windows-2016"
}

variable "dc_disk_size_gb" {
  description = "Disk size (GB) of Domain Controller"
  default = "50" 
}
