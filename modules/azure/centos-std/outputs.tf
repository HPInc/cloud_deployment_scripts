/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "public_instance_ip" {
  #value = "${azurerm_template_deployment.main.outputs["IPAddress"]}" **Outdated Method** 
  value = "${lookup(azurerm_template_deployment.main.outputs, "pubIp", "IPAddress not found")}"
}