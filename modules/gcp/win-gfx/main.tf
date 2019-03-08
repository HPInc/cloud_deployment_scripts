locals {
    prefix = "${var.prefix != "" ? "${var.prefix}-" : ""}"
    # Windows computer names must be <= 15 characters
    # TODO: remove the min() function when Terraform 0.12 is available
    host_name = "${substr("${local.prefix}win-gfx", 0, min(15, length(local.prefix)+7))}"
    setup_file = "C:/Temp/setup.ps1"
}

data "template_file" "sysprep-script" {
    template = "${file("${path.module}/sysprep.ps1.tpl")}"

    vars {
        admin_password = "${var.admin_password}"
    }
}

resource "google_compute_instance" "win-gfx" {
    provider = "google"
    name = "${local.host_name}"
    machine_type = "${var.machine_type}"

    guest_accelerator {
        type = "${var.accelerator_type}"
        count = 1
    }

    scheduling {
        on_host_maintenance = "TERMINATE"
    }

    boot_disk {
        initialize_params {
            image = "projects/${var.disk_image_project}/global/images/family/${var.disk_image_family}"
            type = "pd-ssd"
            size = "${var.disk_size_gb}"
        }
    }

    network_interface {
        subnetwork = "${var.subnet}"
        access_config = {}
    }

    tags = [
        "${local.prefix}tag-rdp",
        "${local.prefix}tag-icmp",
    ]

    metadata {
        sysprep-specialize-script-ps1 = "${data.template_file.sysprep-script.rendered}"
    }
}