locals {
    prefix = "${var.prefix != "" ? "${var.prefix}-" : ""}"
}

resource "google_compute_instance" "dc" {
    provider = "google"
    name = "${local.prefix}domain-controller-vm"
    machine_type = "${var.machine_type}"

    boot_disk {
        initialize_params {
            image = "projects/${var.disk_image_project}/global/images/family/${var.disk_image_family}"
            size = "${var.disk_size_gb}"
        }
    }

    network_interface {
        subnetwork = "${var.subnet}"
        access_config = {}
    }

    tags = [
        "${local.prefix}tag-rdp",
        "${local.prefix}tag-winrm",
    ]
}
