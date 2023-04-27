/*
 * © Copyright 2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "bucket" {
  value = aws_s3_bucket.scripts
}
