resource "google_compute_instance" "dc" {
    provider = "google"
    name = "syin-domain-controller"
    machine_type = "${var.dc_machine_type}"

    boot_disk {
        initialize_params {
            image = "projects/${var.dc_disk_image_project}/global/images/family/${var.dc_disk_image_family}"
            size = "${var.dc_disk_size_gb}"
        }
    }

    network_interface {
        subnetwork = "${var.dc_subnet}"
        access_config = {}
    }
}
