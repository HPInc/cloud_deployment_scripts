variable "prefix" {
  description = "Prefix to add to name of new resources"
  default = ""
}
variable "subnet" {
  description = "Subnet to deploy Domain Controller"
  type = "string"
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
