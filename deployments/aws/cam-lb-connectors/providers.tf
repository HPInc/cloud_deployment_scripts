/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

provider "aws" {
  shared_credentials_file = var.aws_credentials_file
  region                  = var.aws_region
}
