/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
resource "azurerm_resource_group" "main" {
    name     = "${var.prefix}-${var.resource_group_name}"
    location = "${var.azure_region}"
}
resource "azurerm_template_deployment" "main" {
    name                = "ARMTemplate"
    resource_group_name = "${azurerm_resource_group.main.name}"
    template_body       = "${file("./mainTemplate.json")}"
    parameters          = {
        "prefix"                      = "${var.prefix}"
        "location"                    = "${azurerm_resource_group.main.location}"
        "vmSize"                      = "${var.vm_size}"
        "ad_service_account_password" = "${var.ad_service_account_password}"
        "ad_service_account_username" = "${var.ad_service_account_username}"
        "domain_name"                 = "${var.domain_name}"
        "vmName"                      = "${var.prefix}-${var.name}"
        "vNetName"                    = "${var.vnet_name}"
        "vNetRGName"                  = "${var.vnet_rg_name}"
        "adminName"                   = "${var.admin_name}"
        "adminPass"                   = "${var.admin_password}"
        "publicIpAllocationMethod"    = "${var.public_ip_allocation}"
        "TeradiciRegKey"              = "${var.pcoip_registration_code}"
        "_artifactsLocation"          = "${var._artifactsLocation}"
        "_artifactsLocationSasToken"  = "${var._artifactsLocationSasToken}"
    }
    deployment_mode     = "Incremental"
}