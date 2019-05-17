output "Domain Controller Internal IP" {
    value = "${module.dc.internal-ip}"
}

output "Domain Controller Public IP" {
    value = "${module.dc.public-ip}"
}

output "CAC Load Balancer IP" {
    #value = "${data.google_compute_forwarding_rule.cac-fwdrule.ip_address}"
    value = "${google_compute_global_forwarding_rule.cac-fwdrule.ip_address}"
}

output "Win Gfx Internal IP" {
    value = "${module.win-gfx.internal-ip}"
}

output "Win Gfx Public IP" {
    value = "${module.win-gfx.public-ip}"
}

output "CentOS Gfx Internal IP" {
    value = "${module.centos-gfx.internal-ip}"
}

output "CentOS Gfx Public IP" {
    value = "${module.centos-gfx.public-ip}"
}

output "CentOS Std Internal IP" {
    value = "${module.centos-std.internal-ip}"
}

output "CentOS Std Public IP" {
    value = "${module.centos-std.public-ip}"
}
