#!/bin/bash

# © Copyright 2022 HP Development Company, L.P.

# GCP Agent Policies enable automated installation and maintenance of the Google Cloud's operations suite agents across 
# a fleet of VMs that match user-specified criteria. Investigated into creating Agent Policy using Terraform on Feb 8, 2022, 
# but Agent Policy couldn't be created even though all system requirements were met, and required roles were assigned to 
# the service account. Needs further investigation, please see the doc for creating Agent Policy using automation tools at:
# https://registry.terraform.io/modules/terraform-google-modules/cloud-operations/google/latest/submodules/agent-policy

# Setup the GCP Logging agent for a VM instance.
# Array of Log file path is required as parameter(s). e.g. ./ops_setup_linux.sh "/var/log/a.log" "/var/log/b.log"
args=( "$@" )

# Please find the link here: https://cloud.google.com/logging/docs/agent/ops-agent/installation
LOGGING_AGENT_SETUP_URL="https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh"

# Try command until zero exit status or exit(1) when non-zero status after max tries
retry_ops() {
    local retry="$1"         # number of retries
    local retry_delay="$2"   # delay between each retry, in seconds
    local shell_command="$3" # the shell command to run
    local err_message="$4"   # the message to show when the shell command was not successful

    local retry_num=0
    until eval $shell_command
    do
        local rc=$?
        local retry_remain=$((retry-retry_num))

        if [ $retry_remain -eq 0 ]
        then
            log $error_message
            return $rc
        fi

        log "$err_message Retrying in $retry_delay seconds... ($retry_remain retries remaining...)"

        retry_num=$((retry_num+1))
        sleep $retry_delay
    done
}

# To build structure of logging receivers and logging pipelines. 
# Please see the following link for more info about Ops Agent configuration:
# https://cloud.google.com/logging/docs/agent/ops-agent/configuration
# Log file path is required as parameter. e.g. add_ops_config "/var/log/a.log"
add_ops_config() {
    log_file_path="$1"
    # Attempted to use log file full path as log name, but received an error message "Received unexpected value parsing name"
    # So we replace / with - as a workaround. Need to investigate about using full path as log name since 
    # got the following message when trying to escape character: 
    # "Log name contains illegal character. Allowed characters are alphanumerics and ./_-"
    receiver_id=${log_file_path//\//\-}

    c="${receiver_id}:
      type: files
      include_paths:
      - ${log_file_path}
  "

    collect_list+=$c
    receivers_list+=$receiver_id
}

write_ops_config() {
    # configuration template used below was retrieved from https://cloud.google.com/logging/docs/agent/ops-agent/configuration
    cat <<- EOF > /etc/google-cloud-ops-agent/config.yaml
logging:
  receivers:
    ${collect_list[@]}
  service:
    pipelines:
      custom_pipeline:
        receivers: [${receivers_list[@]}]
metrics:
  receivers:
    hostmetrics:
      type: hostmetrics
      collection_interval: 60s
  processors:
    metrics_filter:
      type: exclude_metrics
      metrics_pattern: []
  service:
    pipelines:
      default_pipeline:
        receivers: [hostmetrics]
        processors: [metrics_filter]
EOF
}

log "Downloading Logging Agent from $LOGGING_AGENT_SETUP_URL..."
retry_ops 3  `# 3 retries` \
          10 `# 10s interval` \
          "curl -sSO $LOGGING_AGENT_SETUP_URL" \
          "--> ERROR: Failed to download Logging Agent from from $LOGGING_AGENT_SETUP_URL"

bash add-google-cloud-ops-agent-repo.sh --also-install

log "Configuring OPs Agent..."

collect_list=""
receivers_list=""

for ((i=0; i<${#args[@]}; i+=1))
do
    add_ops_config "${args[i]}"
    if [ $((i+1)) -ne ${#args[@]} ]
    then
        collect_list+="  "
        receivers_list+=", "
    fi
done

log "Writing configurations"
write_ops_config "${args[i]}"

log "Starting OPs Agent..."
service google-cloud-ops-agent restart
# The agent log is available at /var/log/google-cloud-ops-agent/subagents/logging-module.log 

# For formatting purpose so that the next entry printed out to the provisioning.log
# is printed to the next line and is parsable by the Logging Logs agent 
echo " "