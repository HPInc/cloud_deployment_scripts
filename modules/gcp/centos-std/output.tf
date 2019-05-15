output "internal-ip" {
    value = ["${google_compute_instance.centos-std.*.network_interface.0.network_ip}"]
}

output "public-ip" {
    value = ["${google_compute_instance.centos-std.*.network_interface.0.access_config.0.nat_ip}"]
}
