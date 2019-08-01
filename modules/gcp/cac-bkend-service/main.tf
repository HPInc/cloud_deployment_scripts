/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
}

# This is needed so new VMs will be based on the same image in case the public
# images gets updated
data "google_compute_image" "cac-base-img" {
  project = var.disk_image_project
  family  = var.disk_image_family
}

resource "google_compute_instance_template" "cac-template" {
  name_prefix = "${local.prefix}template-cac"

  machine_type = var.machine_type

  disk {
    boot         = true
    source_image = data.google_compute_image.cac-base-img.self_link
    disk_type    = "pd-ssd"
    disk_size_gb = var.disk_size_gb
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

  lifecycle {
    create_before_destroy = true
  }

  metadata = {
    startup-script = <<SCRIPT
            # TODO: installing should be only done if cac is not already installed. Add a check
            # Also check on restart behavior - do the containers restart?

            # download CAC (after DNS is available)
            cd /home/${var.cac_admin_user}
            curl -L ${var.cac_installer_url} -o /home/${var.cac_admin_user}/cloud-access-connector.tar.gz
            tar xzvf /home/${var.cac_admin_user}/cloud-access-connector.tar.gz 

            # wait for service account to be added
            # do this last because it takes a while for new AD user to be added in a new Domain Controller
            # Note: using the domain controller IP instead of the domain name for the
            #       host is more resilient
            echo '### Installing ldap-utils ###'
            RETRIES=5; while true; do sudo apt-get -qq update; sudo apt-get -qq install ldap-utils; RC=$?; if [ $RC -eq 0 ] || [ $RETRIES -eq 0 ]; then break; fi; echo "Error installing ldap-utils. $RETRIES retries remaining..."; RETRIES=$((RETRIES-1)); sleep 5; done

            echo '### Ensure AD account is available ###'
            TIMEOUT=1200; until ldapwhoami -H ldap://${var.domain_controller_ip} -D ${var.service_account_username}@${var.domain_name} -w ${var.service_account_password} -o nettimeout=1; do if [ $TIMEOUT -le 0 ]; then break; else echo "Waiting for AD account ${var.service_account_username}@${var.domain_name} to become available. Retrying in 10 seconds... (Timeout in $TIMEOUT seconds)"; fi; TIMEOUT=$((TIMEOUT-10)); sleep 10; done

            # Install the connector
            export CAM_BASE_URI=${var.cam_url}

            sudo -E /home/${var.cac_admin_user}/cloud-access-connector install -t ${var.cac_token} --accept-policies --insecure --sa-user ${var.service_account_username} --sa-password "${var.service_account_password}" --domain ${var.domain_name} --domain-group "${var.domain_group}" --reg-code ${var.pcoip_registration_code} ${var.ignore_disk_req ? "--ignore-disk-req" : ""} 2>&1 | tee output.txt
    SCRIPT

    ssh-keys = "${var.cac_admin_user}:${file(var.cac_admin_ssh_pub_key_file)}"
  }
}

resource "google_compute_instance_group_manager" "cac-igm" {
  name = "${local.prefix}igm-cac"

  # TODO: makes more sense to use regional IGM
  #region = "${var.gcp_region}"
  zone = var.gcp_zone

  base_instance_name = "${local.prefix}cac"
  instance_template = google_compute_instance_template.cac-template.self_link

  named_port {
    name = "https"
    port = 443
  }

  # Overridden by autoscaler when autoscaler is enabled
  target_size = var.cac_instances
}

resource "google_compute_https_health_check" "cac-hchk" {
  name               = "${local.prefix}hchk-cac"
  request_path       = var.cac_health_check["path"]
  port               = var.cac_health_check["port"]
  check_interval_sec = var.cac_health_check["interval_sec"]
  timeout_sec        = var.cac_health_check["timeout_sec"]
}

resource "google_compute_backend_service" "cac-backend" {
  name = "${local.prefix}bkend-cac"
  port_name = "https"
  protocol = "HTTPS"
  session_affinity = "GENERATED_COOKIE"
  affinity_cookie_ttl_sec = 3600

  backend {
    balancing_mode = "UTILIZATION"

    # Wants instanceGroup instead of instanceGroupManager
    group = replace(
      google_compute_instance_group_manager.cac-igm.self_link,
      "Manager",
      "",
    )
  }

  health_checks = [google_compute_https_health_check.cac-hchk.self_link]
}

