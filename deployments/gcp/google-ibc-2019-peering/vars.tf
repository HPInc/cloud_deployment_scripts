/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "gcp_credentials_file" {
  description = "Location of GCP JSON credentials file"
  type        = string
}

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_service_account" {
  description = "Service Account in the GCP Project"
  type        = string
}

variable "prefix" {
  description = "Prefix to add to name of new resources. Must be <= 9 characters."
  default     = ""
}

variable "vpc_name" {
  description = "Name of VPC to create"
  default     = "vpc-cam"
}

variable "workstation_vpc_names" {
  description = "Names of VPC in which to deploy workstations"
  type        = list(string)
}
