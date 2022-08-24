/*
 * © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

resource "google_logging_metric" "connection-metric" {
  count           = var.gcp_ops_agent_enable ? var.instance_count : 0

  name            = "${local.prefix}${var.host_name}-${var.gcp_region}-${count.index}-connections"
  filter          = "resource.type=\"gce_instance\" AND labels.\"compute.googleapis.com/resource_name\"=\"${local.prefix}${var.host_name}-${var.gcp_region}-${count.index}\" AND jsonPayload.message:\"UDP connections currently working\""
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
      key         = "connections"
      value_type  = "INT64"
      description = "number of connections"
    }
  }

  label_extractors = {
    "connections" = "REGEXP_EXTRACT(jsonPayload.message, \"get_statistics returning ([0-9]*) UDP connections currently working\")"
  }
}

resource "google_monitoring_dashboard" "connector-dashboard" {
  count          = var.gcp_ops_agent_enable ? var.instance_count : 0
  
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
