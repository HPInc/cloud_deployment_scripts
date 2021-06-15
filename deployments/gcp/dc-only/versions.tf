/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

terraform {
  required_version = ">= 1.0"
  required_providers {
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 3.49.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 3.49.0"
    }
    http = {
      source = "hashicorp/http"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}
