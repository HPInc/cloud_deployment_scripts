/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix   = var.prefix != "" ? "${var.prefix}-" : ""
  cert_dir = "/home/${var.cac_admin_user}"
  ssl      = var.ssl_key != "" ? true : false
}

resource "google_compute_instance" "cac" {
  count = var.instance_count

  provider = google
  zone     = var.gcp_zone

  name         = "${local.prefix}${var.host_name}-${count.index}"
  machine_type = var.machine_type

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "projects/${var.disk_image_project}/global/images/family/${var.disk_image_family}"
      type  = "pd-ssd"
      size  = var.disk_size_gb
    }
  }

  network_interface {
    subnetwork = var.subnet
    access_config {
    }
  }

  tags = [
    "${local.prefix}tag-ssh",
    "${local.prefix}tag-icmp",
    "${local.prefix}tag-http",
    "${local.prefix}tag-https",
    "${local.prefix}tag-pcoip",
  ]

  metadata = {
    startup-script = <<SCRIPT
            sudo echo '# System Control network settings for CAC' > /etc/sysctl.d/01-pcoip-cac-network.conf
            sudo echo 'net.core.rmem_max=160000000' >> /etc/sysctl.d/01-pcoip-cac-network.conf
            sudo echo 'net.core.rmem_default=160000000' >> /etc/sysctl.d/01-pcoip-cac-network.conf
            sudo echo 'net.core.wmem_max=160000000' >> /etc/sysctl.d/01-pcoip-cac-network.conf
            sudo echo 'net.core.wmem_default=160000000' >> /etc/sysctl.d/01-pcoip-cac-network.conf
            sudo echo 'net.ipv4.udp_mem=120000 240000 600000' >> /etc/sysctl.d/01-pcoip-cac-network.conf
            sudo echo 'net.core.netdev_max_backlog=2000' >> /etc/sysctl.d/01-pcoip-cac-network.conf
            sudo sysctl -p /etc/sysctl.d/01-pcoip-cac-network.conf
    SCRIPT

    ssh-keys = "${var.cac_admin_user}:${file(var.cac_admin_ssh_pub_key_file)}"
  }
}

resource "null_resource" "cac-dependencies" {
  count = var.instance_count

  depends_on = [google_compute_instance.cac]

  triggers = {
    instance_id = google_compute_instance.cac[count.index].instance_id
  }

  connection {
    type = "ssh"
    user = var.cac_admin_user
    private_key = file(var.cac_admin_ssh_priv_key_file)
    host = google_compute_instance.cac[count.index].network_interface[0].access_config[0].nat_ip
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      # download CAC (after DNS is available)
      "curl -L ${var.cac_installer_url} -o /home/${var.cac_admin_user}/cloud-access-connector.tar.gz",
      "tar xzvf /home/${var.cac_admin_user}/cloud-access-connector.tar.gz",

      # Wait for service account to be added
      # do this last because it takes a while for new AD user to be added in a
      # new Domain Controller
      # Note: using the domain controller IP instead of the domain name for the
      #       host is more resilient
      "sudo apt install -y ldap-utils",
      "TIMEOUT=1200",
      "until ldapwhoami -H ldap://${var.domain_controller_ip} -D ${var.service_account_username}@${var.domain_name} -w ${var.service_account_password} -o nettimeout=1; do if [ $TIMEOUT -le 0 ]; then break; else echo \"Waiting for AD account ${var.service_account_username}@${var.domain_name} to become available. Retrying in 10 seconds... (Timeout in $TIMEOUT seconds)\"; fi; TIMEOUT=$((TIMEOUT-10)); sleep 10; done",
    ]
  }
}

resource "null_resource" "install-cac" {
  count = local.ssl == true ? 0 : var.instance_count

  depends_on = [null_resource.cac-dependencies]

  triggers = {
    instance_id = google_compute_instance.cac[count.index].instance_id
  }

  connection {
    type = "ssh"
    user = var.cac_admin_user
    private_key = file(var.cac_admin_ssh_priv_key_file)
    host = google_compute_instance.cac[count.index].network_interface[0].access_config[0].nat_ip
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "export CAM_BASE_URI=${var.cam_url}",
      "sudo -E /home/${var.cac_admin_user}/cloud-access-connector install -t ${var.cac_token} --accept-policies --insecure --sa-user ${var.service_account_username} --sa-password \"${var.service_account_password}\" --domain ${var.domain_name} --domain-group \"${var.domain_group}\" --reg-code ${var.pcoip_registration_code} ${var.ignore_disk_req ? "--ignore-disk-req" : ""} 2>&1 | tee output.txt",
      "sudo docker service ls",
    ]
  }
}

resource "null_resource" "install-cac-cert" {
  count = local.ssl == true ? var.instance_count : 0

  depends_on = [null_resource.cac-dependencies]

  triggers = {
    instance_id = google_compute_instance.cac[count.index].instance_id
  }

  connection {
    type = "ssh"
    user = var.cac_admin_user
    private_key = file(var.cac_admin_ssh_priv_key_file)
    host = google_compute_instance.cac[count.index].network_interface[0].access_config[0].nat_ip
    insecure = true
  }

  provisioner "file" {
    source = var.ssl_key
    destination = "${local.cert_dir}/${basename(var.ssl_key)}"
  }

  provisioner "file" {
    source = var.ssl_cert
    destination = "${local.cert_dir}/${basename(var.ssl_cert)}"
  }

  provisioner "remote-exec" {
    inline = [
      "export CAM_BASE_URI=${var.cam_url}",
      "sudo -E /home/${var.cac_admin_user}/cloud-access-connector install -t ${var.cac_token} --accept-policies --ssl-key ${local.cert_dir}/${basename(var.ssl_key)} --ssl-cert ${local.cert_dir}/${basename(var.ssl_cert)} --sa-user ${var.service_account_username} --sa-password \"${var.service_account_password}\" --domain ${var.domain_name} --domain-group \"${var.domain_group}\" --reg-code ${var.pcoip_registration_code} ${var.ignore_disk_req ? "--ignore-disk-req" : ""} 2>&1 | tee output.txt",
      "sudo docker service ls",
    ]
  }
}
