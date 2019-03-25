output "Domain Controller Internal IP" {
    value = "${module.dc.internal-ip}"
}

output "Domain Controller Public IP" {
    value = "${module.dc.public-ip}"
}
