output "cac-igm" {
    value = "${google_compute_region_instance_group_manager.cac-igm.self_link}"
}

output "cac-scaler" {
    value = "${google_compute_region_autoscaler.cac-scaler.self_link}"
}