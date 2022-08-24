/*
 * © Copyright 2022 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

resource "google_logging_metric" "overall-connection-metric" {
  count           = var.gcp_ops_agent_enable ? 1 : 0

  name            = "overall-connections"
  filter          = "resource.type=\"gce_instance\" AND jsonPayload.message:\"UDP connections currently working\""
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

resource "google_logging_metric" "users-metric" {
  count           = var.gcp_ops_agent_enable ? 1 : 0

  name            = "user_num"
  filter          = "resource.type=\"gce_instance\" AND jsonPayload.message:\"Users in active directory\""
  value_extractor = "REGEXP_EXTRACT(jsonPayload.message, \"Found ([0-9]*) users\")"

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
      key        = "users"
      value_type = "INT64"
    }
  }

  label_extractors = {
    "users" = "REGEXP_EXTRACT(jsonPayload.message, \"Found ([0-9]*) users\")"
  }
}

resource "google_logging_metric" "machines-metric" {
  count           = var.gcp_ops_agent_enable ? 1 : 0

  name            = "machine_num"
  filter          = "resource.type=\"gce_instance\" AND jsonPayload.message:\"Machines in active directory\""
  value_extractor = "REGEXP_EXTRACT(jsonPayload.message, \"Found ([0-9]*) machines\")"

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
      key        = "machines"
      value_type = "INT64"
    }
  }

  label_extractors = {
    "machines" = "REGEXP_EXTRACT(jsonPayload.message, \"Found ([0-9]*) machines\")"
  }
}

resource "google_logging_metric" "latency-metric" {
  count           = var.gcp_ops_agent_enable ? 1 : 0

  name            = "top5-latency"
  filter          = "resource.type=\"gce_instance\" AND jsonPayload.message:\"Tx thread info: round trip time\""
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
      key        = "latency"
      value_type = "INT64"
    }
  }

  label_extractors = {
    "latency" = "REGEXP_EXTRACT(jsonPayload.message, \"= (.*), variance\")"
  }
}

resource "google_logging_metric" "rxloss-metric" {
  count           = var.gcp_ops_agent_enable ? 1 : 0

  name            = "top10-rxloss"
  filter          = "resource.type=\"gce_instance\" AND jsonPayload.message:\"(A/I/O) Loss=\""
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
      key        = "rxloss"
      value_type = "INT64"
    }
  }

  label_extractors = {
    "rxloss" = "REGEXP_EXTRACT(jsonPayload.message, \"\\\\(A/I/O\\\\) Loss=(.*)%/\")"
  }
}

resource "google_logging_metric" "txloss-metric" {
  count           = var.gcp_ops_agent_enable ? 1 : 0
  
  name            = "top10-txloss"
  filter          = "resource.type=\"gce_instance\" AND jsonPayload.message:\"(A/I/O) Loss=\""
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
      key        = "txloss"
      value_type = "INT64"
    }
  }

  label_extractors = {
    "txloss" = "REGEXP_EXTRACT(jsonPayload.message, \"%/(.*)% \\\\(R/T\\\\)\")"
  }
}

resource "google_logging_metric" "txdata-metric" {
  count           = var.gcp_ops_agent_enable ? 1 : 0

  name            = "top5-txdata"
  filter          = "resource.type=\"gce_instance\" AND jsonPayload.message:\"MGMT_PCOIP_DATA :Tx thread info: bw limit\""
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
      key        = "txdata"
      value_type = "INT64"
    }
  }

  label_extractors = {
    "txdata" = "REGEXP_EXTRACT(jsonPayload.message, \"avg tx = (.*),\")"
  }
}

resource "google_logging_metric" "rxdata-metric" {
  count           = var.gcp_ops_agent_enable ? 1 : 0

  name            = "top5-rxdata"
  filter          = "resource.type=\"gce_instance\" AND jsonPayload.message:\"MGMT_PCOIP_DATA :Tx thread info: bw limit\""
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
      key        = "rxdata"
      value_type = "INT64"
    }
  }

  label_extractors = {
    "rxdata" = "REGEXP_EXTRACT(jsonPayload.message, \"avg rx = (.*) \\\\(kbit\")"
  }
}

resource "google_monitoring_dashboard" "overall-dashboard" {
  count          = var.gcp_ops_agent_enable ? 1 : 0

  dashboard_json = <<EOF
{
  "category": "CUSTOM",
  "displayName": "${local.prefix}overall",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [     
      {
        "height": 4,
        "widget": {
          "title": "Number of Machines in AD",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "STACKED_BAR",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "apiSource": "DEFAULT_CLOUD",
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"machines\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.machines-metric[count.index].id}\" resource.type=\"gce_instance\"",
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
          "title": "Number of Users in AD",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "STACKED_BAR",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "apiSource": "DEFAULT_CLOUD",
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metric.label.\"users\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.users-metric[count.index].id}\" resource.type=\"gce_instance\"",
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
          "title": "Active Connections",
          "timeSeriesTable": {
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "tableDisplayOptions": {},
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_MEAN",
                      "groupByFields": [
                        "metadata.system_labels.\"name\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.overall-connection-metric[count.index].id}\" resource.type=\"gce_instance\"",
                    "pickTimeSeriesFilter": {
                      "direction": "BOTTOM",
                      "numTimeSeries": 300,
                      "rankingMethod": "METHOD_MEAN"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "NUMBER"
          }
        },
        "width": 4,
        "xPos": 0,
        "yPos": 4
      },
      {
        "height": 4,
        "widget": {
          "timeSeriesTable": {
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "tableDisplayOptions": {},
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_99",
                      "groupByFields": [
                        "metadata.system_labels.\"name\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.latency-metric[count.index].id}\" resource.type=\"gce_instance\"",
                    "pickTimeSeriesFilter": {
                      "direction": "BOTTOM",
                      "numTimeSeries": 5,
                      "rankingMethod": "METHOD_MEAN"
                    },
                    "secondaryAggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_NONE"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "NUMBER"
          },
          "title": "Top 5 PCoIP Agent Latency"
        },
        "width": 4,
        "xPos": 4,
        "yPos": 4
      },
      {
        "height": 4,
        "widget": {
          "timeSeriesTable": {
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "tableDisplayOptions": {},
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_99",
                      "groupByFields": [
                        "metadata.system_labels.\"name\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.rxloss-metric[count.index].id}\" resource.type=\"gce_instance\"",
                    "pickTimeSeriesFilter": {
                      "direction": "BOTTOM",
                      "numTimeSeries": 10,
                      "rankingMethod": "METHOD_MEAN"
                    },
                    "secondaryAggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_NONE"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "NUMBER"
          },
          "title": "Top 10 PCoIP Agent Packet Loss (Received)"
        },
        "width": 4,
        "xPos": 8,
        "yPos": 4
      },
      {
        "height": 4,
        "widget": {
          "timeSeriesTable": {
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "tableDisplayOptions": {},
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_99",
                      "groupByFields": [
                        "metadata.system_labels.\"name\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.txloss-metric[count.index].id}\" resource.type=\"gce_instance\"",
                    "pickTimeSeriesFilter": {
                      "direction": "BOTTOM",
                      "numTimeSeries": 10,
                      "rankingMethod": "METHOD_MEAN"
                    },
                    "secondaryAggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_NONE"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "NUMBER"
          },
          "title": "Top 10 PCoIP Agent Packet Loss (Transmitted)"
        },
        "width": 4,
        "xPos": 0,
        "yPos": 8
      },
      {
        "height": 4,
        "widget": {
          "timeSeriesTable": {
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "tableDisplayOptions": {},
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_99",
                      "groupByFields": [
                        "metadata.system_labels.\"name\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.rxdata-metric[count.index].id}\" resource.type=\"gce_instance\"",
                    "pickTimeSeriesFilter": {
                      "direction": "BOTTOM",
                      "numTimeSeries": 5,
                      "rankingMethod": "METHOD_MEAN"
                    },
                    "secondaryAggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_NONE"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "NUMBER"
          },
          "title": "Top 5 PCoIP Agent Data Received"
        },
        "width": 4,
        "xPos": 4,
        "yPos": 8
      },
      {
        "height": 4,
        "widget": {
          "timeSeriesTable": {
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "tableDisplayOptions": {},
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_99",
                      "groupByFields": [
                        "metadata.system_labels.\"name\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.txdata-metric[count.index].id}\" resource.type=\"gce_instance\"",
                    "pickTimeSeriesFilter": {
                      "direction": "BOTTOM",
                      "numTimeSeries": 5,
                      "rankingMethod": "METHOD_MEAN"
                    },
                    "secondaryAggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_NONE",
                      "perSeriesAligner": "ALIGN_NONE"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "NUMBER"
          },
          "title": "Top 5 PCoIP Agent Data Transmitted"
        },
        "width": 4,
        "xPos": 8,
        "yPos": 8
      }
    ]
  }
}
EOF
}
