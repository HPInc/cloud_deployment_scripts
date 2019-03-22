output "Domain Controller Internal IP" {
    value = "${module.dc.internal-ip}"
}

output "Domain Controller Public IP" {
    value = "${module.dc.public-ip}"
}

output "CAC-0 Public IP" {
    value = "${module.cac-0.public-ip}"
}

output "CAC-1 Public IP" {
    value = "${module.cac-1.public-ip}"
}

output "CAC-2 Public IP" {
    value = "${module.cac-2.public-ip}"
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
