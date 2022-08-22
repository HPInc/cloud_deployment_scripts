/*
 * © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  enable_public_ip    = (var.enable_awc_external_ip || var.external_pcoip_ip == "") ? [true] : []
  prefix              = var.prefix != "" ? "${var.prefix}-" : ""
  provisioning_script = "awc-provisioning.sh"
}

resource "google_storage_bucket_object" "awc-provisioning-script" {
  count = var.instance_count == 0 ? 0 : 1

  bucket  = var.bucket_name
  name    = "${local.provisioning_script}-${var.gcp_region}"
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      ad_service_account_password = var.ad_service_account_password,
      ad_service_account_username = var.ad_service_account_username,
      awc_extra_install_flags     = var.awc_extra_install_flags,
      bucket_name                 = var.bucket_name,
      cas_mgr_deployment_sa_file  = var.cas_mgr_deployment_sa_file,
      cas_mgr_insecure            = var.cas_mgr_insecure ? "true" : "", 
      cas_mgr_script              = var.cas_mgr_script,
      cas_mgr_url                 = var.cas_mgr_url,
      computers_dn                = var.computers_dn,
      domain_controller_ip        = var.domain_controller_ip,
      domain_name                 = var.domain_name,
      external_pcoip_ip           = var.external_pcoip_ip,
      gcp_ops_agent_enable        = var.gcp_ops_agent_enable,
      kms_cryptokey_id            = var.kms_cryptokey_id,
      ldaps_cert_filename         = var.ldaps_cert_filename,
      ops_setup_script            = var.ops_setup_script,
      tls_cert                    = var.tls_cert_filename,
      tls_key                     = var.tls_key_filename,
      teradici_download_token     = var.teradici_download_token,
      users_dn                    = var.users_dn
    }
  )
}

data "google_compute_zones" "available" {
  region = var.gcp_region
  status = "UP"
}

resource "random_shuffle" "zone" {
  input        = data.google_compute_zones.available.names
  result_count = var.instance_count
}

resource "google_compute_instance" "awc" {
  count = var.instance_count

  name         = "${local.prefix}${var.host_name}-${var.gcp_region}-${count.index}"
  zone         = random_shuffle.zone.result[count.index]
  machine_type = var.machine_type

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.disk_image
      type  = "pd-ssd"
      size  = var.disk_size_gb
    }
  }

  network_interface {
    subnetwork = var.subnet

    dynamic access_config {
      for_each = local.enable_public_ip
      content {}
    }
  }

  tags = var.network_tags

  metadata = {
    ssh-keys = "${var.awc_admin_user}:${file(var.awc_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.awc-provisioning-script[0].output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}

resource "google_logging_metric" "connection-metric" {
  count = var.gcp_ops_agent_enable ? var.instance_count : 0
  name = "${local.prefix}${var.host_name}-${var.gcp_region}-${count.index}-connections"
  filter = "resource.type=\"gce_instance\" AND labels.\"compute.googleapis.com/resource_name\"=\"${local.prefix}${var.host_name}-${var.gcp_region}-${count.index}\" AND jsonPayload.message:\"UDP connections currently working\""
  value_extractor = "REGEXP_EXTRACT(jsonPayload.message, \"get_statistics returning ([0-9]*) UDP connections currently working\")"

  bucket_options {
    exponential_buckets {
      num_finite_buckets = 64
      growth_factor      = 2
      scale              = 0.01
    }
  }
  
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    labels {
      key = "connections"
      value_type = "INT64"
      description = "number of connections"
    }
  }
  
  label_extractors = {
    "connections" = "REGEXP_EXTRACT(jsonPayload.message, \"get_statistics returning ([0-9]*) UDP connections currently working\")"
  }
}

resource "google_monitoring_dashboard" "connector-dashboard" {
  count = var.gcp_ops_agent_enable ? var.instance_count : 0
  dashboard_json = <<EOF
{
  "category": "CUSTOM",
  "displayName": "${local.prefix}${var.host_name}-${var.gcp_region}-${count.index}",
  "mosaicLayout": {
    "columns": 4,
    "tiles": [
      {
        "height": 2,
        "width": 2,
        "widget": {
          "title": "Active Connections",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "STACKED_AREA",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "apiSource": "DEFAULT_CLOUD",
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.connection-metric[count.index].id}\" resource.type=\"gce_instance\""
                  }
                }
              }
            ],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "y1Axis",
              "scale": "LINEAR"
            }
          }
        },
        "xPos": 0,
        "yPos": 0
      },
      {
        "height": 2,
        "widget": {
          "title": "CPU Utilization",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "apiSource": "DEFAULT_CLOUD",
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_MEAN"
                    },
                    "filter": "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" resource.type=\"gce_instance\" resource.labels.instance_id=\"${google_compute_instance.awc[count.index].instance_id}\" "
                  }
                }
              }
            ],
            "thresholds": [],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "y1Axis",
              "scale": "LINEAR"
            }
          }
        },
        "width": 2,
        "xPos": 2,
        "yPos": 0
      },
      {
        "height": 2,
        "widget": {
          "title": "Received bytes",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "apiSource": "DEFAULT_CLOUD",
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_RATE"
                    },
                    "filter": "metric.type=\"compute.googleapis.com/instance/network/received_bytes_count\" resource.type=\"gce_instance\" resource.labels.instance_id=\"${google_compute_instance.awc[count.index].instance_id}\" ",
                    "secondaryAggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_MEAN"
                    }
                  }
                }
              }
            ],
            "thresholds": [],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "y1Axis",
              "scale": "LINEAR"
            }
          }
        },
        "width": 2,
        "xPos": 0,
        "yPos": 2
      },
      {
        "height": 2,
        "widget": {
          "title": "Sent bytes",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "apiSource": "DEFAULT_CLOUD",
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_RATE"
                    },
                    "filter": "metric.type=\"compute.googleapis.com/instance/network/sent_bytes_count\" resource.type=\"gce_instance\" resource.labels.instance_id=\"${google_compute_instance.awc[count.index].instance_id}\" ",
                    "secondaryAggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_MEAN"
                    }
                  }
                }
              }
            ],
            "thresholds": [],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "y1Axis",
              "scale": "LINEAR"
            }
          }
        },
        "width": 2,
        "xPos": 2,
        "yPos": 2
      }
    ]
  }
}
EOF
}
