#!/bin/bash

# Copyright (c) 2021 Teradici Corporation

# Setup the AWS CloudWatch Logs agent for an EC2 instance.
# The following parameters are required in the order of:
#   1. Region
#   2. Array with the following information:
#       a. Log file path
#       b. DateTime format


CLOUDWATCH_AGENT_SETUP_URL="https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py"
AWSLOGS_CONFIG_FILE="awslogs.conf"

# Try command until zero exit status or exit(1) when non-zero status after max tries
retry() {
    local counter="$1"
    local interval="$2"
    local command="$3"
    local log_message="$4"
    local err_message="$5"
    local count=0

    while [ true ]
    do
        ((count=count+1))
        eval $command && break
        if [ $count -gt $counter ]
        then
            log "$err_message"
            return 1
        else
            log "$log_message Retrying in $interval seconds"
            sleep $interval
        fi
    done
}

init_awslogs_config(){
    # This general section is required
    configurations+=(
        "[general]"
        "state_file = /var/awslogs/state/agent-state"
    )
}

add_awslogs_config(){
    log_file_path="$1"
    datetime_format="$2"
    log_file_name="$(basename $log_file_path)"

    configurations+=(
        "[$log_file_name]"
        "log_group_name = $instance_name"
        "log_stream_name = $log_file_name"
        "datetime_format = $datetime_format"
        "time_zone = LOCAL"
        "file = $log_file_path"
        "multi_line_start_pattern = {datetime_format}"
        "initial_position = end_of_file"
        "encoding = [ascii]"
        "buffer_duration = 5000"
    )
}

write_awslogs_config(){
    for ((i=0; i<${#configurations[@]}; i++))
    do
        output+="${configurations[$i]}"
        output+=$'\n'
    done
    echo "$output" > "$AWSLOGS_CONFIG_FILE"
}

log "Downloading CloudWatch Agent Setup Script from $CLOUDWATCH_AGENT_SETUP_URL..."
retry 3 5 "curl $CLOUDWATCH_AGENT_SETUP_URL -O" "-->" "--> ERROR: Failed to download CloudWatch Agent Setup Script."
chmod +x ./awslogs-agent-setup.py

log "Configuring CloudWatch Agent..."
configurations=()

init_awslogs_config

args=( "$@" )
REGION="${args[0]}"

instance_id=$(retry 3 5 "curl http://169.254.169.254/latest/meta-data/instance-id" "-->" "--> ERROR: Failed to get the instance id.")

while [ -z "${instance_name}" ]
do
    instance_name=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=Name" --output text | cut -f5)
done

for ((i=1; i<${#args[@]}; i++))
do
    add_awslogs_config "${args[i]}" "${args[++i]}"
done

log "Writing configurations to $AWSLOGS_CONFIG_FILE"
write_awslogs_config

log "Starting CloudWatch Agent..."
python ./awslogs-agent-setup.py --region $REGION --configfile $AWSLOGS_CONFIG_FILE -n
# The script will also create a folder /var/awslogs 
# The logs are available at /var/log/awslogs.log and /var/log/awslogs-agent-setup.log 

echo " "

