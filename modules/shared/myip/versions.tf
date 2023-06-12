/*
 * © Copyright 2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

terraform {
  required_version = ">= 1.0"
  required_providers {
    http = {
      source = "hashicorp/http"
      version = ">= 3.3.0" # with retry option
    }
  }
}
