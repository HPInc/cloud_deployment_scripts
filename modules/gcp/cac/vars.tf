variable "prefix" {
  description = "Prefix to add to name of new resources"
  default = ""
}

variable "cam_url" {
  description = "Cloud Access Manager URL"
  default = "https://cam.teradici.com"
}

variable "pcoip_registration_code" {
  description = "PCoIP Registration code"
  type = "string"
}

variable "cac_token" {
  description = "Connector Token from CAM Service"
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

variable "domain_group" {
  description = "Active Directory Distinguished Name for the User Group to log into the CAM Management Interface. Default is 'Domain Admins'. (eg, 'CN=CAM Admins,CN=Users,DC=example,DC=com')"
  default = "Domain Admins"
}

variable "service_account_username" {
  description = "Active Directory Service Account username"
  type = "string"
}

variable "service_account_password" {
  description = "Active Directory Service Account password"
  type = "string"
}

variable "zone" {
  description = "Zone to deploy the Cloud Access Connector"
  default = "us-west2-b"
}

variable "subnet" {
  description = "Subnet to deploy the Cloud Access Connector"
  type = "string"
}

variable "instance_count" {
  description = "Number of Cloud Access Connectors to deploy"
  default = 1
}

variable "host_name" {
  description = "Name to give the host"
  default = "vm-cac"
}

variable "machine_type" {
  description = "Machine type for the Cloud Access Connector"
  default = "n1-standard-2"
}

variable "disk_image_project" {
  description = "Disk image project for the Cloud Access Connector"
  default = "ubuntu-os-cloud"
}

variable "disk_image_family" {
  description = "Disk image family for the Cloud Access Connector"
  default = "ubuntu-1804-lts"
}

variable "disk_size_gb" {
  description = "Disk size (GB) of the Cloud Access Connector"
  default = "50"
}

variable "cac_admin_user" {
  description = "Username of the Cloud Access Connector Administrator"
  type = "string"
}

variable "cac_admin_ssh_pub_key_file" {
  description = "SSH public key for the Cloud Access Connector Administrator"
  type = "string"
}

variable "cac_admin_ssh_priv_key_file" {
  description = "SSH private key for the Cloud Access Connector Administrator"
  type = "string"
}

variable "cac_installer_url" {
  description = "Location of the Cloud Access Connector installer"
  default = "https://teradici.bintray.com/cloud-access-connector/cloud-access-connector-0.1.1.tar.gz"
}

variable "ignore_disk_req" {
  description = "Ignore the check for the minimum disk space requirement when installing the Cloud Access Connector"
  default = true
}

variable "ssl_key" {
  description = "SSL private key for the Connector"
  default = ""
}

variable "ssl_cert" {
  description = "SSL certificate for the Connector"
  default = ""
}