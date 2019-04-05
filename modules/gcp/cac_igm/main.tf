locals {
    prefix = "${var.prefix != "" ? "${var.prefix}-" : ""}"
    cert_dir = "/home/${var.cac_admin_user}"
    ssl = "${var.ssl_key != "" ? true : false }"
}

# This is needed so new VMs will be based on the same image in case the public
# images gets updated
data "google_compute_image" "cac-base-img" {
    project = "${var.disk_image_project}"
    family  = "${var.disk_image_family}"
}

resource "google_compute_instance_template" "cac-template" {
    name_prefix = "${local.prefix}tpl-cac"

    machine_type = "${var.machine_type}"

    disk {
        boot = true
        source_image = "${data.google_compute_image.cac-base-img.self_link}"
        disk_type = "pd-ssd"
        disk_size_gb = "${var.disk_size_gb}"
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

    lifecycle {
        create_before_destroy = true
    }

    metadata {
        startup-script = <<SCRIPT
            # Add domain controller to list of name servers and domain to list of searches
            echo "            nameservers:" >> /etc/netplan/50-cloud-init.yaml
            echo "                search: [${var.domain_name}]" >> /etc/netplan/50-cloud-init.yaml
            echo "                addresses: [${var.domain_controller_ip}]" >> /etc/netplan/50-cloud-init.yaml
            netplan apply

            # wait for domain controller DNS to be ready
            # Cannot do this too early.  Otherwise the domain controller reboots and the domain will not be resolved again.
            until host ${var.domain_name} > /dev/null; do echo 'Trying to resolve ${var.domain_name}. Retrying in 10 seconds...'; sleep 10; sudo netplan apply; done

            # TODO: installing should be only done if cac is not already installed. Add a check
            # Also check on restart behavior - do the containers restart?

            # download CAC (after DNS is available)
            cd /home/${var.cac_admin_user}
            curl -L ${var.cac_installer_url} -o /home/${var.cac_admin_user}/cloud-access-connector.tar.gz
            echo `whoami` > whoami
            tar xzvf /home/${var.cac_admin_user}/cloud-access-connector.tar.gz 

            # wait for service account to be added
            # do this last because it takes a while for new AD user to be added in a new Domain Controller
            sudo apt install -y ldap-utils
            until ldapwhoami -H ldap://${var.domain_name} -D ${var.service_account_username}@${var.domain_name} -w ${var.service_account_password} > /dev/null 2>&1; do echo 'Waiting for AD account ${var.service_account_username}@${var.domain_name} to become available. Retrying in 10 seconds...'; sleep 10; sudo netplan apply; done

            export CAM_BASE_URI=${var.cam_url}

            sudo -E /home/${var.cac_admin_user}/cloud-access-connector install -t ${var.cac_token} --accept-policies --insecure --sa-user ${var.service_account_username} --sa-password "${var.service_account_password}" --domain ${var.domain_name} --domain-group "${var.domain_group}" --reg-code ${var.pcoip_registration_code} ${var.ignore_disk_req ? "--ignore-disk-req" : ""} 2>&1 | tee output.txt
        SCRIPT

        ssh-keys = "${var.cac_admin_user}:${file("${var.cac_admin_ssh_pub_key_file}")}"
    }
}

resource "google_compute_region_instance_group_manager" "cac-igm" {
    name   = "${local.prefix}igm-cac"

    region = "${var.gcp_region}"

    base_instance_name = "${local.prefix}cac"
    instance_template = "${google_compute_instance_template.cac-template.self_link}"

    named_port {
        name = "https"
        port = 443
    }
}

resource "google_compute_region_autoscaler" "cac-scaler" {
    name = "${local.prefix}scaler-cac"

    region = "${var.gcp_region}"
    target = "${google_compute_region_instance_group_manager.cac-igm.self_link}"

    autoscaling_policy {
        max_replicas    = 3
        min_replicas    = 2
        # CAC install takes about 5 mins
        cooldown_period = 300

        cpu_utilization {
            target = 0.6
        }
    }
}
