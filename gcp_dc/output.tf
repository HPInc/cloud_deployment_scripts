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

output "CAC SSH command" {
    value = "${module.cac.ssh}"
}