provider "google" {
    credentials = "${file("${var.gcp_credentials_file}")}"
    project   = "${var.gcp_project_id}"
    zone      = "${var.gcp_zone}"
}

module "dc" {
    source = "../modules/gcp/dc"

    dc_subnet = "${var.dc_subnet}"
}