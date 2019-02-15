locals {
    prefix = "${var.prefix != "" ? "${var.prefix}-" : ""}"
    host_name = "${local.prefix}domain-controller-vm"
    private_ip = "${var.private_ip != "" ? "${var.private_ip}" : ""}"
    setup_file = "C:/Temp/setup.ps1"
    add_user_file = "C:/Temp/add_user.ps1"
}

data "template_file" "sysprep-script" {
    template = "${file("${path.module}/sysprep.ps1.tpl")}"

    vars {
        admin_password = "${var.admin_password}"
    }
}

data "template_file" "setup-script" {
    template = "${file("${path.module}/setup.ps1.tpl")}"

    vars {
        domain_name = "${var.domain_name}"
        safe_mode_admin_password = "${var.safe_mode_admin_password}"
    }
}

data "template_file" "add-user-script" {
    template = "${file("${path.module}/add_user.ps1.tpl")}"

    vars {
        host_name = "${local.host_name}"
        domain_name = "${var.domain_name}"
        svcaccount_password = "${var.svcaccount_password}"
    }
}

resource "google_compute_instance" "dc" {
    provider = "google"
    name = "${local.host_name}"
    machine_type = "${var.machine_type}"

    boot_disk {
        initialize_params {
            image = "projects/${var.disk_image_project}/global/images/family/${var.disk_image_family}"
            type = "pd-ssd"
            size = "${var.disk_size_gb}"
        }
    }

    network_interface {
        subnetwork = "${var.subnet}"
        network_ip = "${local.private_ip}"
        access_config = {}
    }

    tags = [
        "${local.prefix}tag-rdp",
        "${local.prefix}tag-winrm",
        "${local.prefix}tag-icmp",
    ]

    metadata {
        sysprep-specialize-script-ps1 = "${data.template_file.sysprep-script.rendered}"
    }
}

resource "null_resource" "upload-scripts" {
    depends_on = ["google_compute_instance.dc"]
    triggers {
        instance_id = "${google_compute_instance.dc.instance_id}"
    }

    connection {
        type = "winrm"
        user = "Administrator"
        password = "${var.admin_password}"
        host = "${google_compute_instance.dc.network_interface.0.access_config.0.nat_ip}"
        port = "5986"
        https = "true"
        insecure = "true"
    }

    provisioner "file" {
        content = "${data.template_file.setup-script.rendered}"
        destination = "${local.setup_file}"
    }

    provisioner "file" {
        content = "${data.template_file.add-user-script.rendered}"
        destination = "${local.add_user_file}"
    }
}

resource "null_resource" "run-setup-script" {
    depends_on = ["null_resource.upload-scripts"]
    triggers {
        instance_id = "${google_compute_instance.dc.instance_id}"
    }

    connection {
        type = "winrm"
        user = "Administrator"
        password = "${var.admin_password}"
        host = "${google_compute_instance.dc.network_interface.0.access_config.0.nat_ip}"
        port = "5986"
        https = "true"
        insecure = "true"
    }

    provisioner "remote-exec" {
        inline = ["powershell -file ${local.setup_file}"]
    }
}

resource "null_resource" "wait-for-reboot" {
    depends_on = ["null_resource.run-setup-script"]
    triggers {
        instance_id = "${google_compute_instance.dc.instance_id}"
    }

    provisioner "local-exec" {
        command = "sleep 15"
    }
}

resource "null_resource" "add-user" {
    depends_on = ["null_resource.wait-for-reboot"]
    triggers {
        instance_id = "${google_compute_instance.dc.instance_id}"
    }

    connection {
        type = "winrm"
        user = "Administrator"
        password = "${var.admin_password}"
        host = "${google_compute_instance.dc.network_interface.0.access_config.0.nat_ip}"
        port = "5986"
        https = "true"
        insecure = "true"
    }

    provisioner "remote-exec" {
        inline = ["powershell -file ${local.add_user_file}"]
    }
}
