#!/bin/bash

# Copyright (c) 2021 Teradici Corporation

# Setup the AWS CloudWatch Logs agent for an EC2 instance.
# The following parameters are required in the order of:
#   1. Region
#   2. Array with the following information:
#       a. Log file path
#       b. DateTime format

args=( "$@" )
REGION="${args[0]}"

# Please find the link here: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/download-cloudwatch-agent-commandline.html
CLOUDWATCH_AGENT_SETUP_URL="https://s3.$REGION.amazonaws.com/amazoncloudwatch-agent-$REGION/centos/amd64/latest/amazon-cloudwatch-agent.rpm"
CLOUDWATCH_CONFIG_FILE="cloudwatch.conf"

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

add_cloudwatch_config(){
    log_file_path="$1"
    datetime_format="$2"

    c="{
                        \"file_path\": \"$log_file_path\",
                        \"log_group_name\": \"$instance_name\",
                        \"log_stream_name\": \"$log_file_path\",
                        \"timestamp_format\": \"$datetime_format\",
                        \"timezone\": \"LOCAL\",
                        \"multi_line_start_pattern\": \"{timestamp_format}\",
                        \"encoding\": \"ascii\"
                    }"

    collect_list+=$c
}

write_cloudwatch_config(){
    cat <<- EOF > $CLOUDWATCH_CONFIG_FILE
{
    "logs": {   
        "logs_collected": {
            "files": {
                "collect_list": [
                    ${collect_list[@]}
                ]
            }
        }
    }
}
			EOF
}

log "Downloading CloudWatch Agent from $CLOUDWATCH_AGENT_SETUP_URL..."
retry 3 5 "curl -O $CLOUDWATCH_AGENT_SETUP_URL" "-->" "--> ERROR: Failed to download the CloudWatch Agent."
rpm -U ./$(basename $CLOUDWATCH_AGENT_SETUP_URL)

log "Configuring CloudWatch Agent..."

collect_list=""

instance_id=$(retry 3 5 "curl http://169.254.169.254/latest/meta-data/instance-id" "-->" "--> ERROR: Failed to get the instance id.")

while [ -z "${instance_name}" ]
do
    instance_name=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=Name" --output text | cut -f5)
done

for ((i=1; i<${#args[@]}; i+=2))
do
    add_cloudwatch_config "${args[i]}" "${args[i+1]}"
    if [ $((i+2)) -ne ${#args[@]} ]
    then
        collect_list+=","
    fi
done

log "Writing configurations to $CLOUDWATCH_CONFIG_FILE"
write_cloudwatch_config

log "Starting CloudWatch Agent..."
aws configure set region $REGION
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:$CLOUDWATCH_CONFIG_FILE
# The script will also create a folder /var/logs/amazon 
# The logs are available at /var/log/amazon/amazon-cloudwatch-agent/amazon-cloudwatch-agent.log 

# For formatting purpose so that the next entry printed out to the provisioning.log
# is printed to the next line and is parsable by the CloudWatch Logs agent 
echo " "

