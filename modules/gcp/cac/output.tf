output "internal-ip" {
    value = "${google_compute_instance.cac.network_interface.0.network_ip}"
}

output "public-ip" {
    value = "${google_compute_instance.cac.network_interface.0.access_config.0.nat_ip}"
}

output "ssh" {
    value = "ssh -i ${var.cac_admin_ssh_priv_key_file} ${var.cac_admin_user}@${google_compute_instance.cac.network_interface.0.access_config.0.nat_ip}"
}