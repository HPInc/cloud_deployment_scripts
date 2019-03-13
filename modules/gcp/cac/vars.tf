variable "prefix" {
  description = "Prefix to add to name of new resources"
  default = ""
}
variable "subnet" {
  description = "Subnet to deploy the Cloud Access Connector"
  type = "string"
}

variable "instance_count" {
  description = "Number of Cloud Access Connectors to deploy"
  default = 1
}

variable "machine_type" {
  description = "Machine type for Cloud Access Controller"
  default = "n1-standard-2"
}

variable "disk_image_project" {
  description = "Disk image project for Cloud Access Controller"
  default = "ubuntu-os-cloud"
}

variable "disk_image_family" {
  description = "Disk image family for Cloud Access Controller"
  default = "ubuntu-1804-lts"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of Cloud Access Controller"
  default = "50" 
}

variable "domain_name" {
  description = "Name of the domain to join"
  type = "string"
}

variable "domain_controller_ip" {
  description = "Internal IP of the Domain Controller"
  type = "string"
}

variable "cac_admin_user" {
  description = "Username of Cloud Access Connector Administrator"
  type = "string"
}

variable "cac_admin_ssh_pub_key_file" {
  description = "SSH public key for Cloud Access Connector Administrator"
  type = "string"
}

variable "cac_admin_ssh_priv_key_file" {
  description = "SSH private key for Cloud Access Connector Administrator"
  type = "string"
}

variable "cac_installer_url" {
  description = "Location of Cloud Access Connector installer"
  default = "https://teradici.bintray.com/cloud-access-connector/cloud-access-connector-0.1.1.tar.gz"
}

variable "cam_url" {
  description = "cam server url."
  default = "https://cam.teradici.com"
}

variable "token" {
  description = "AUTH Token from CAM Service"
  type = "string"
}

variable "service_account_user" {
  description = "Active Directory Service Account username"
  type = "string"
}

variable "service_account_password" {
  description = "Active Directory Service Account password"
  type = "string"
}

variable "domain_group" {
  description = "Active Directory Distinguished Name for the User Group to log into the CAM Management Interface. Default is 'Domain Admins'. (eg, 'CN=CAM Admins,CN=Users,DC=example,DC=com')"
  default = "Domain Admins"
}

variable "registration_code" {
  description = "PCoIP Registration code"
  type = "string"
}

variable "ignore_disk_req" {
  description = "Ignore the check for the minimum disk space requirement"
  default = true
}