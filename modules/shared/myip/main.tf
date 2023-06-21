/*
 * © Copyright 2021-2023 HP Development Company, L.P
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * This module can be used to get my public IP address.
 * The public IP may be used by firewall, ACL, security groups, etc.
 */

data "http" "myip" {
  url = var.url
  # Retry in case of network congestions
  retry {
    attempts     = var.retry_attempts
    min_delay_ms = 10
    max_delay_ms = 100
  }
}
