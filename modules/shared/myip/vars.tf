/*
 * © Copyright 2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "url" {
  description = "The URL will response with my public IP."
  default     = "https://cas.teradici.com/api/v1/health"
}

variable "retry_attempts" {
  description = "Retry attempt to get URL in case of network congestions"
  default     = 3
}
