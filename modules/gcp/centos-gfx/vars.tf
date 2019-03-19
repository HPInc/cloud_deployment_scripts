variable "prefix" {
  description = "Prefix to add to name of new resources"
  default = ""
}

variable "machine_type" {
  description = "Machine type for CentOS Workstation"
  default = "n1-standard-2"
}

variable "accelerator_type" {
  description = "Accelerator type for Workstation"
  default = "nvidia-tesla-p4-vws"
}

variable "accelerator_count" {
  description = "Number of GPUs for Workstation"
  default = "1"
}

variable "disk_image_project" {
  description = "Disk image project for CentOS Workstation"
  default = "centos-cloud"
}

variable "disk_image_family" {
  description = "Disk image family for CentOS Workstation"
  default = "centos-7"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of CentOS Workstation"
  default = "50"
}

variable "subnet" {
  description = "Subnet to deploy the CentOS Workstation"
  type = "string"
}

variable "ws_admin_user" {
  description = "Username of CentOS Workstation Administrator"
  type = "string"
}

variable "ws_admin_ssh_pub_key_file" {
  description = "SSH public key for CentOS Workstation Administrator"
  type = "string"
}

variable "ws_admin_ssh_priv_key_file" {
  description = "SSH private key for CentOS Workstation Administrator"
  type = "string"
}

variable "domain_name" {
  description = "Name of the domain to join"
  type = "string"
}

variable "domain_controller_ip" {
  description = "Internal IP of the Domain Controller"
  type = "string"
}

variable "service_account_username" {
  description = "Active Directory Service Account username"
  type = "string"
}

variable "service_account_password" {
  description = "Active Directory Service Account password"
  type = "string"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type = "string"
}
