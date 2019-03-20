provider "google" {
    credentials = "${file("${var.gcp_credentials_file}")}"
    project   = "${var.gcp_project_id}"
    region    = "${var.gcp_region}"
    zone      = "${var.gcp_zone}"
}

locals {
    prefix = "${var.prefix != "" ? "${var.prefix}-" : ""}"
}

resource "google_compute_network" "vpc" {
    name = "${local.prefix}vpc-dc"
    auto_create_subnetworks = "false"
}

resource "google_compute_firewall" "allow-internal" {
    name = "${local.prefix}fw-allow-internal"
    network = "${google_compute_network.vpc.self_link}"

    allow = [
        {
            protocol = "icmp"
        },
        {
            protocol = "tcp"
            ports = ["1-65535"]
        },
        {
            protocol = "udp"
            ports = ["1-65535"]
        }
    ]

    source_ranges = ["${var.dc_subnet_cidr}", "${var.cac_subnet_cidr}", "${var.ws_subnet_cidr}"]
}

resource "google_compute_firewall" "allow-ssh" {
    name = "${local.prefix}fw-allow-ssh"
    network = "${google_compute_network.vpc.self_link}"

    allow = [
        {
            protocol = "tcp"
            ports = ["22"]
        }
    ]

    target_tags = ["${local.prefix}tag-ssh"]
    source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-http" {
    name = "${local.prefix}fw-allow-http"
    network = "${google_compute_network.vpc.self_link}"

    allow = [
        {
            protocol = "tcp"
            ports = ["80"]
        }
    ]

    target_tags = ["${local.prefix}tag-http"]
    source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-https" {
    name = "${local.prefix}fw-allow-https"
    network = "${google_compute_network.vpc.self_link}"

    allow = [
        {
            protocol = "tcp"
            ports = ["443"]
        }
    ]

    target_tags = ["${local.prefix}tag-https"]
    source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-rdp" {
    name = "${local.prefix}fw-allow-rdp"
    network = "${google_compute_network.vpc.self_link}"

    allow = [
        {
            protocol = "tcp"
            ports = ["3389"]
        },
        {
            protocol = "udp"
            ports = ["3389"]
        }
    ]

    target_tags = ["${local.prefix}tag-rdp"]
    source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-winrm" {
    name = "${local.prefix}fw-allow-winrm"
    network = "${google_compute_network.vpc.self_link}"

    allow = [
        {
            protocol = "tcp"
            ports = ["5985"]
        },
        {
            protocol = "tcp"
            ports = ["5986"]
        }
    ]

    target_tags = ["${local.prefix}tag-winrm"]
    source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-icmp" {
    name = "${local.prefix}fw-allow-icmp"
    network = "${google_compute_network.vpc.self_link}"

    allow = [{protocol = "icmp"}]

    target_tags = ["${local.prefix}tag-icmp"]
    source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-pcoip" {
    name = "${local.prefix}fw-allow-pcoip"
    network = "${google_compute_network.vpc.self_link}"

    allow = [
        {
            protocol = "tcp"
            ports = ["4172"]
        },
        {
            protocol = "udp"
            ports = ["4172"]
        }
    ]

    target_tags = ["${local.prefix}tag-pcoip"]
    source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_subnetwork" "dc-subnet" {
    name = "${local.prefix}subnet-dc"
    ip_cidr_range = "${var.dc_subnet_cidr}"
    network = "${google_compute_network.vpc.self_link}"
}

resource "google_compute_address" "dc-internal-ip" {
    name = "${local.prefix}static-ip-internal-dc"
    subnetwork = "${google_compute_subnetwork.dc-subnet.self_link}"
    address_type = "INTERNAL"
    address = "${var.dc_private_ip}"
}

module "dc" {
    source = "../../../modules/gcp/dc"

    prefix = "${var.prefix}"

    domain_name              = "${var.domain_name}"
    admin_password           = "${var.dc_admin_password}"
    safe_mode_admin_password = "${var.safe_mode_admin_password}"
    service_account_username = "${var.service_account_username}"
    service_account_password = "${var.service_account_password}"

    subnet     = "${google_compute_subnetwork.dc-subnet.self_link}"
    private_ip = "${var.dc_private_ip}"

    machine_type       = "${var.dc_machine_type}"
    disk_image_project = "${var.dc_disk_image_project}"
    disk_image_family  = "${var.dc_disk_image_family}"
    disk_size_gb       = "${var.dc_disk_size_gb}"
}

resource "google_compute_subnetwork" "cac-subnet" {
    name = "${local.prefix}subnet-cac"
    ip_cidr_range = "${var.cac_subnet_cidr}"
    network = "${google_compute_network.vpc.self_link}"
}

module "cac" {
    source = "../../../modules/gcp/cac"

    prefix = "${var.prefix}"

    cam_url                 = "${var.cam_url}"
    pcoip_registration_code = "${var.pcoip_registration_code}"
    cac_token               = "${var.cac_token}"

    domain_name              = "${var.domain_name}"
    domain_controller_ip     = "${module.dc.internal-ip}"
    service_account_username = "${var.service_account_username}"
    service_account_password = "${var.service_account_password}"

    subnet         = "${google_compute_subnetwork.cac-subnet.self_link}"
    instance_count = "${var.cac_instance_count}"

    machine_type       = "${var.cac_machine_type}"
    disk_image_project = "${var.cac_disk_image_project}"
    disk_image_family  = "${var.cac_disk_image_family}"
    disk_size_gb       = "${var.cac_disk_size_gb}"

    cac_admin_user              = "${var.cac_admin_user}"
    cac_admin_ssh_pub_key_file  = "${var.cac_admin_ssh_pub_key_file}"
    cac_admin_ssh_priv_key_file = "${var.cac_admin_ssh_priv_key_file}"
}

resource "google_compute_subnetwork" "ws-subnet" {
    name = "${local.prefix}subnet-ws"
    ip_cidr_range = "${var.ws_subnet_cidr}"
    network = "${google_compute_network.vpc.self_link}"
}

module "win-gfx" {
    source = "../../../modules/gcp/win-gfx"

    prefix = "${var.prefix}"

    pcoip_registration_code = "${var.pcoip_registration_code}"

    domain_name              = "${var.domain_name}"
    domain_controller_ip     = "${module.dc.internal-ip}"
    service_account_username = "${var.service_account_username}"
    service_account_password = "${var.service_account_password}"

    gcp_project_id = "${var.gcp_project_id}"
    subnet         = "${google_compute_subnetwork.ws-subnet.self_link}"

    admin_password = "${var.dc_admin_password}"
}

module "centos-gfx" {
    source = "../../../modules/gcp/centos-gfx"

    prefix = "${var.prefix}"

    pcoip_registration_code = "${var.pcoip_registration_code}"

    domain_name              = "${var.domain_name}"
    domain_controller_ip     = "${module.dc.internal-ip}"
    service_account_username = "${var.service_account_username}"
    service_account_password = "${var.service_account_password}"

    subnet = "${google_compute_subnetwork.ws-subnet.self_link}"

    ws_admin_user              = "${var.centos_admin_user}"
    ws_admin_ssh_pub_key_file  = "${var.centos_admin_ssh_pub_key_file}"
    ws_admin_ssh_priv_key_file = "${var.centos_admin_ssh_priv_key_file}"

}