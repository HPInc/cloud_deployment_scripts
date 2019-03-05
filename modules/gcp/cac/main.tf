locals {
    prefix = "${var.prefix != "" ? "${var.prefix}-" : ""}"
    host_name = "${local.prefix}vm-cac"
}

resource "google_compute_instance" "cac" {
    count = "${var.instance_count}"

    provider = "google"
    name = "${local.host_name}-${count.index}"
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
        access_config = {}
    }

    tags = [
        "${local.prefix}tag-ssh",
        "${local.prefix}tag-icmp",
        "${local.prefix}tag-http",
        "${local.prefix}tag-https",
        "${local.prefix}tag-pcoip",
    ]

    metadata {
        startup-script = <<SCRIPT
            sudo echo "            nameservers:" >> /etc/netplan/50-cloud-init.yaml
            sudo echo "                search: [${var.domain_name}]" >> /etc/netplan/50-cloud-init.yaml
            sudo echo "                addresses: [${var.domain_controller_ip}]" >> /etc/netplan/50-cloud-init.yaml
            sudo netplan apply
        SCRIPT

        ssh-keys = "${var.cac_admin_user}:${file("${var.cac_admin_ssh_pub_key_file}")}"
    }
}

resource "null_resource" "cac-dependencies" {
    count = "${var.instance_count}"

    depends_on = ["google_compute_instance.cac"]

    triggers {
        instance_id = "${google_compute_instance.cac.*.instance_id[count.index]}"
    }

    connection {
        type = "ssh"
        user = "${var.cac_admin_user}"
        private_key = "${file(var.cac_admin_ssh_priv_key_file)}"
        host = "${google_compute_instance.cac.*.network_interface.0.access_config.0.nat_ip[count.index]}"
        insecure = true
    }

    provisioner "remote-exec" {
        inline = [
            # wait for domain controller DNS to be ready
            # Cannot do this too early.  Otherwise the domain controller reboots and the domain will not be resolved again.
            "until host ${var.domain_name} > /dev/null; do echo 'Trying to resolve ${var.domain_name}. Retrying in 10 seconds...'; sleep 10; sudo netplan apply; done",

            # download CAC (after DNS is available)
            "curl -L ${var.cac_installer_url} -o /home/${var.cac_admin_user}/cloud-access-connector.tar.gz",
            "tar xzvf /home/${var.cac_admin_user}/cloud-access-connector.tar.gz",

            # wait for service account to be added
            # do this last because it takes a while for new AD user to be added in a new Domain Controller
            "sudo apt install -y ldap-utils",
            "until ldapwhoami -H ldap://${var.domain_name} -D ${var.service_account_user}@${var.domain_name} -w ${var.service_account_password} > /dev/null 2>&1; do echo 'Waiting for AD account ${var.service_account_user}@${var.domain_name} to become available. Retrying in 10 seconds...'; sleep 10; sudo netplan apply; done"
        ]
    }
}

resource "null_resource" "install-cac" {
    count = "${var.instance_count}"

    depends_on = ["null_resource.cac-dependencies"]

    triggers {
        instance_id = "${google_compute_instance.cac.*.instance_id[count.index]}"
    }

    connection {
        type = "ssh"
        user = "${var.cac_admin_user}"
        private_key = "${file(var.cac_admin_ssh_priv_key_file)}"
        host = "${google_compute_instance.cac.*.network_interface.0.access_config.0.nat_ip[count.index]}"
        insecure = true
    }

    provisioner "remote-exec" {
        inline = [
            "export CAM_BASE_URI=${var.cam_url}",

            # TODO: remove for security.
            # Save command used for reference
            "echo \"-E /home/${var.cac_admin_user}/cloud-access-connector install -t ${var.token} --accept-policies --insecure --sa-user ${var.service_account_user} --sa-password \"${var.service_account_password}\" --domain ${var.domain_name} --reg-code ${var.registration_code} ${var.ignore_disk_req ? "--ignore-disk-req" : ""}\" > cmd.txt",

            "sudo -E /home/${var.cac_admin_user}/cloud-access-connector install -t ${var.token} --accept-policies --insecure --sa-user ${var.service_account_user} --sa-password \"${var.service_account_password}\" --domain ${var.domain_name} --reg-code ${var.registration_code} ${var.ignore_disk_req ? "--ignore-disk-req" : ""} 2>&1 | tee output.txt",

            "sudo docker service ls",
        ]
    }
}
