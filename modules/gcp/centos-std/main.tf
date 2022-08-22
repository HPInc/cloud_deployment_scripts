/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""

  # Windows computer names must be <= 15 characters, minus 4 chars for "-xyz"
  # where xyz is number of instances (0-999)
  host_name = substr("${local.prefix}${var.instance_name}", 0, 11)
  instance_info_list = flatten(
    [ for i in range(length(var.zone_list)):
      [ for j in range(var.instance_count_list[i]):
        {
          zone   = var.zone_list[i],
          subnet = var.subnet_list[i],
        }
      ]
    ]
  )
  enable_public_ip = var.enable_public_ip ? [true] : []
  provisioning_script = "centos-std-provisioning.sh"
}

resource "google_storage_bucket_object" "centos-std-provisioning-script" {
  count = length(local.instance_info_list) == 0 ? 0 : 1

  name    = local.provisioning_script
  bucket  = var.bucket_name
  content = templatefile(
    "${path.module}/${local.provisioning_script}.tmpl",
    {
      ad_service_account_password = var.ad_service_account_password,
      ad_service_account_username = var.ad_service_account_username,
      bucket_name                 = var.bucket_name, 
      domain_controller_ip        = var.domain_controller_ip,
      domain_name                 = var.domain_name,
      gcp_ops_agent_enable        = var.gcp_ops_agent_enable,
      kms_cryptokey_id            = var.kms_cryptokey_id,
      ops_setup_script            = var.ops_setup_script,
      pcoip_registration_code     = var.pcoip_registration_code,
      teradici_download_token     = var.teradici_download_token,

      auto_logoff_cpu_utilization                = var.auto_logoff_cpu_utilization,
      auto_logoff_enable                         = var.auto_logoff_enable,
      auto_logoff_minutes_idle_before_logoff     = var.auto_logoff_minutes_idle_before_logoff,
      auto_logoff_polling_interval_minutes       = var.auto_logoff_polling_interval_minutes,
      idle_shutdown_cpu_utilization              = var.idle_shutdown_cpu_utilization,
      idle_shutdown_enable                       = var.idle_shutdown_enable,
      idle_shutdown_minutes_idle_before_shutdown = var.idle_shutdown_minutes_idle_before_shutdown,
      idle_shutdown_polling_interval_minutes     = var.idle_shutdown_polling_interval_minutes,
    }
  )
}

resource "google_compute_instance" "centos-std" {
  count = length(local.instance_info_list)

  provider     = google
  name         = "${local.host_name}-${count.index}"
  zone         = local.instance_info_list[count.index].zone
  machine_type = var.machine_type

  boot_disk {
    initialize_params {
      image = var.disk_image
      type  = "pd-ssd"
      size  = var.disk_size_gb
    }
  }

  network_interface {
    subnetwork = local.instance_info_list[count.index].subnet

    dynamic access_config {
      for_each = local.enable_public_ip
      content {}
    }
  }

  tags = var.network_tags

  metadata = {
    ssh-keys = "${var.ws_admin_user}:${file(var.ws_admin_ssh_pub_key_file)}"
    startup-script-url = "gs://${var.bucket_name}/${google_storage_bucket_object.centos-std-provisioning-script[0].output_name}"
  }

  service_account {
    email = var.gcp_service_account == "" ? null : var.gcp_service_account
    scopes = ["cloud-platform"]
  }
}

resource "google_logging_metric" "latency-metric" {
  count = var.gcp_ops_agent_enable ? length(local.instance_info_list) : 0
  name = "${local.host_name}-${count.index}-latency"
  filter = "resource.type=\"gce_instance\" AND labels.\"compute.googleapis.com/resource_name\"=\"${local.host_name}-${count.index}\" AND jsonPayload.message:\"Tx thread info: round trip time\""
  value_extractor = "REGEXP_EXTRACT(jsonPayload.message, \"= (.*), variance\")"

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
      key = "latency"
      value_type = "INT64"
    }
  }
  
  label_extractors = {
    "latency" = "REGEXP_EXTRACT(jsonPayload.message, \"= (.*), variance\")"
  }
}

resource "google_logging_metric" "rxloss-metric" {
  count = var.gcp_ops_agent_enable ? length(local.instance_info_list) : 0
  name = "${local.host_name}-${count.index}-rxloss"
  filter = "resource.type=\"gce_instance\" AND labels.\"compute.googleapis.com/resource_name\"=\"${local.host_name}-${count.index}\" AND jsonPayload.message:\"(A/I/O) Loss=\""
  value_extractor = "REGEXP_EXTRACT(jsonPayload.message, \"\\\\(A/I/O\\\\) Loss=(.*)%/\")"

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
      key = "rxloss"
      value_type = "INT64"
    }
  }
  
  label_extractors = {
    "rxloss" = "REGEXP_EXTRACT(jsonPayload.message, \"\\\\(A/I/O\\\\) Loss=(.*)%/\")"
  }
}

resource "google_logging_metric" "txloss-metric" {
  count = var.gcp_ops_agent_enable ? length(local.instance_info_list) : 0
  name = "${local.host_name}-${count.index}-txloss"
  filter = "resource.type=\"gce_instance\" AND labels.\"compute.googleapis.com/resource_name\"=\"${local.host_name}-${count.index}\" AND jsonPayload.message:\"(A/I/O) Loss=\""
  value_extractor = "REGEXP_EXTRACT(jsonPayload.message, \"%/(.*)% \\\\(R/T\\\\)\")"

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
      key = "txloss"
      value_type = "INT64"
    }
  }
  
  label_extractors = {
    "txloss" = "REGEXP_EXTRACT(jsonPayload.message, \"%/(.*)% \\\\(R/T\\\\)\")"
  }
}

resource "google_logging_metric" "txdata-metric" {
  count = var.gcp_ops_agent_enable ? length(local.instance_info_list) : 0
  name = "${local.host_name}-${count.index}-txdata"
  filter = "resource.type=\"gce_instance\" AND labels.\"compute.googleapis.com/resource_name\"=\"${local.host_name}-${count.index}\" AND jsonPayload.message:\"MGMT_PCOIP_DATA :Tx thread info: bw limit\""
  value_extractor = "REGEXP_EXTRACT(jsonPayload.message, \"avg tx = (.*),\")"

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
      key = "txdata"
      value_type = "INT64"
    }
  }
  
  label_extractors = {
    "txdata" = "REGEXP_EXTRACT(jsonPayload.message, \"avg tx = (.*),\")"
  }
}

resource "google_logging_metric" "rxdata-metric" {
  count = var.gcp_ops_agent_enable ? length(local.instance_info_list) : 0
  name = "${local.host_name}-${count.index}-rxdata"
  filter = "resource.type=\"gce_instance\" AND labels.\"compute.googleapis.com/resource_name\"=\"${local.host_name}-${count.index}\" AND jsonPayload.message:\"MGMT_PCOIP_DATA :Tx thread info: bw limit\""
  value_extractor = "REGEXP_EXTRACT(jsonPayload.message, \"avg rx = (.*) \\\\(kbit\")"

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
      key = "rxdata"
      value_type = "INT64"
    }
  }
  
  label_extractors = {
    "rxdata" = "REGEXP_EXTRACT(jsonPayload.message, \"avg rx = (.*) \\\\(kbit\")"
  }
}

resource "google_monitoring_dashboard" "scent-dashboard" {
  count = var.gcp_ops_agent_enable ? length(local.instance_info_list) : 0
  dashboard_json = <<EOF
{
  "category": "CUSTOM",
  "displayName": "${local.host_name}-${count.index}",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "height": 4,
        "widget": {
          "title": "Latency (ms)",
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
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.latency-metric[count.index].id}\" resource.type=\"gce_instance\"",
                    "secondaryAggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_NONE"
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
        "width": 6,
        "xPos": 0,
        "yPos": 0
      },
      {
        "height": 4,
        "widget": {
          "title": "RxLoss (%)",
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
                      "perSeriesAligner": "ALIGN_PERCENTILE_95"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.rxloss-metric[count.index].id}\" resource.type=\"gce_instance\"",
                    "secondaryAggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_NONE"
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
        "width": 6,
        "xPos": 6,
        "yPos": 0
      },
      {
        "height": 4,
        "widget": {
          "title": "TxLoss (%)",
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
                      "perSeriesAligner": "ALIGN_PERCENTILE_95"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.txloss-metric[count.index].id}\" resource.type=\"gce_instance\"",
                    "secondaryAggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_NONE"
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
        "width": 6,
        "xPos": 0,
        "yPos": 4
      },
      {
        "height": 4,
        "widget": {
          "title": "Data Received (KB)",
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
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"rxdata\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.rxdata-metric[count.index].id}\" resource.type=\"gce_instance\""
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
        "width": 6,
        "xPos": 6,
        "yPos": 4
      },
      {
        "height": 4,
        "widget": {
          "title": "Data Transmitted (KB)",
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
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"txdata\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.txdata-metric[count.index].id}\" resource.type=\"gce_instance\""
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
        "width": 6,
        "xPos": 0,
        "yPos": 8
      },
      {
        "height": 4,
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
                    "filter": "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" resource.type=\"gce_instance\" resource.labels.instance_id=\"${google_compute_instance.centos-std[count.index].instance_id}\" "
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
        "width": 6,
        "xPos": 6,
        "yPos": 8
      }
    ]
  }
}
EOF
}
