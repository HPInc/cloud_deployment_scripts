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

    source_ranges = ["${var.dc_subnet_cidr}"]
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

resource "google_compute_subnetwork" "subnet" {
    name = "${local.prefix}subnet-dc"
    ip_cidr_range = "${var.dc_subnet_cidr}"
    network = "${google_compute_network.vpc.self_link}"
}

resource "google_compute_address" "dc-internal-ip" {
    name = "${local.prefix}static-ip-internal-dc"
    subnetwork = "${google_compute_subnetwork.subnet.self_link}"
    address_type = "INTERNAL"
    address = "${var.dc_private_ip}"
}

module "dc" {
    source = "../modules/gcp/dc"

    prefix = "${var.prefix}"
    subnet = "${google_compute_subnetwork.subnet.self_link}"
    private_ip = "${var.dc_private_ip}"
    machine_type = "${var.dc_machine_type}"
    disk_image_project = "${var.dc_disk_image_project}"
    disk_image_family = "${var.dc_disk_image_family}"
    disk_size_gb = "${var.dc_disk_size_gb}"
    admin_password = "${var.dc_admin_password}"
    domain_name = "${var.domain_name}"
    safe_mode_admin_password = "${var.safe_mode_admin_password}"
    svcaccount_password = "${var.svcaccount_password}"
}