locals {
    prefix = "${var.prefix != "" ? "${var.prefix}-" : ""}"
    # Windows computer names must be <= 15 characters, minus 3 chars for "-xy"
    # where xy is number of instances (0-99)
    # TODO: remove the min() function when Terraform 0.12 is available
    host_name = "${substr("${local.prefix}${var.name}", 0, min(12, length(local.prefix)+length(var.name)))}"

    setup_dir= "/tmp"
}

resource "google_compute_instance" "centos-gfx" {
    count = "${var.instance_count}"

    provider = "google"
    name = "${local.host_name}-${count.index}"
    machine_type = "${var.machine_type}"

    guest_accelerator {
        type = "${var.accelerator_type}"
        count = "${var.accelerator_count}"
    }

    # This is needed to prevent "Instances with guest accelerators do not support live migration" error
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
        "${local.prefix}tag-ssh",
        "${local.prefix}tag-icmp",
    ]

    metadata {
        ssh-keys = "${var.ws_admin_user}:${file("${var.ws_admin_ssh_pub_key_file}")}"

        # TODO: may need to find a better way to run the script.  If the script
        # is removed, subsequent reboots will loop forever.
        startup-script = <<EOF
            if ! (rpm -q pcoip-agent-graphics)
            then
                export DOMAIN_NAME="${var.domain_name}"
                export USERNAME="${var.service_account_username}"
                export PASSWORD="${var.service_account_password}"
                export IP_ADDRESS="${var.domain_controller_ip}"
                export REGISTRATION_CODE="${var.pcoip_registration_code}"

                provsion_script_file="${local.setup_dir}/provisioning-gpu-script.sh"

                until [[ -f "$provsion_script_file" ]]
                do
                    echo "Waiting for script to be uploaded, retrying in 10 seconds..."
                    sleep 10
                done

                chmod +x ${local.setup_dir}/provisioning-gpu-script.sh
                ${local.setup_dir}/provisioning-gpu-script.sh
            fi
        EOF
    }
}

resource "null_resource" "upload-scripts" {
    count = "${var.instance_count}"

    depends_on = ["google_compute_instance.centos-gfx"]
    triggers {
        instance_id = "${google_compute_instance.centos-gfx.*.instance_id[count.index]}"
    }

    connection {
        type = "ssh"
        host = "${google_compute_instance.centos-gfx.*.network_interface.0.access_config.0.nat_ip[count.index]}"
        user = "${var.ws_admin_user}"
        private_key = "${file(var.ws_admin_ssh_priv_key_file)}"
        insecure = true
    }

    provisioner "file" {
        source = "${path.module}/provisioning-gpu-script.sh"
        destination = "${local.setup_dir}/provisioning-gpu-script.sh"
    }
}

