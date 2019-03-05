output "Domain Controller Internal IP" {
    value = "${module.dc.internal-ip}"
}

output "Domain Controller Public IP" {
    value = "${module.dc.public-ip}"
}

output "CAC Internal IP" {
    value = "${module.cac.internal-ip}"
}

output "CAC Public IP" {
    value = "${module.cac.public-ip}"
}

output "CAC TCP Network Load Balancer IP" {
    value = "${data.google_compute_forwarding_rule.cac-fwdrule.ip_address}"
}