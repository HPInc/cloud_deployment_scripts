#!/bin/bash

# Copyright (c) 2021 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#############
# Variables #
#############
# REQUIRED: You must fill in this value before running the script
PCOIP_REGISTRATION_CODE=""

# OPTIONAL: You can use the default value set here or change it
TERADICI_DOWNLOAD_TOKEN="yj39yHtgj68Uv2Qf"


exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

LOG_FILE="/var/log/teradici/provisioning.log"
METADATA_IP="http://169.254.169.254"
TERADICI_REPO_SETUP_SCRIPT_URL="https://dl.teradici.com/$TERADICI_DOWNLOAD_TOKEN/pcoip-agent/cfg/setup/bash.rpm.sh"

log() {
    local message="$1"
    echo "[$(date)] $message"
}

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

check_required_vars() {
    set +x

    if [[ -z "$PCOIP_REGISTRATION_CODE" ]]; then
        log "--> ERROR: Missing PCoIP Registration Code."
        missing_vars="true"
    fi

    set -x

    if [[ "$missing_vars" = "true" ]]; then
        log "--> Exiting..."
        exit 1
    fi
}

exit_and_restart() {
    log "--> Rebooting..."
    (sleep 1; reboot -p) &
    exit
}

install_pcoip_agent() {
    log "--> Getting Teradici PCoIP agent repo..."
    curl --retry 3 --retry-delay 5 -u "token:$TERADICI_DOWNLOAD_TOKEN" -1sLf $TERADICI_REPO_SETUP_SCRIPT_URL | bash
    if [ $? -ne 0 ]; then
        log "--> ERROR: Failed to install PCoIP agent repo."
        exit 1
    fi
    log "--> PCoIP agent repo installed successfully."

    log "--> Installing USB dependencies..."
    retry   3 \
            5 \
            "yum install -y usb-vhci" \
            "--> Non-zero exit status." \
            "--> Warning: Failed to install usb-vhci."

    log "--> Installing PCoIP standard agent..."
    retry   3 \
            5 \
            "yum -y install pcoip-agent-standard" \
            "--> Non-zero exit status." \
            "--> ERROR: Failed to download PCoIP agent."
    if [ $? -eq 1 ]; then
        exit 1
    fi
    log "--> PCoIP agent installed successfully."

    set +x
    if [[ "$PCOIP_REGISTRATION_CODE" ]]; then
        log "--> Registering PCoIP agent license..."
        n=0
        while true; do
            /usr/sbin/pcoip-register-host --registration-code="$PCOIP_REGISTRATION_CODE" && break
            n=$[$n+1]

            if [ $n -ge 10 ]; then
                log "--> ERROR: Failed to register PCoIP agent after $n tries."
                exit 1
            fi

            log "--> ERROR: Failed to register PCoIP agent. Retrying in 10s..."
            sleep 10
        done
        log "--> PCoIP agent registered successfully."

    else
        log "--> No PCoIP Registration Code provided. Skipping PCoIP agent registration..."
    fi
    set -x
}

# Open up firewall for PCoIP Agent. By default eth0 is in firewall zone "public"
update_firewall() {
    log "--> Adding 'pcoip-agent' service to public firewall zone..."
    firewall-offline-cmd --zone=public --add-service=pcoip-agent
    systemctl enable firewalld
    systemctl start firewalld
}

if (rpm -q pcoip-agent-standard); then
    exit
fi

if [[ ! -f "$LOG_FILE" ]]
then
    mkdir -p "$(dirname $LOG_FILE)"
    touch "$LOG_FILE"
    chmod +644 "$LOG_FILE"
fi

log "$(date)"

# Print all executed commands to the terminal
set -x

# Redirect stdout and stderr to the log file
exec &>>$LOG_FILE

# EPEL needed for GraphicsMagick-c++, required by PCoIP Agent
yum -y install epel-release
yum -y update
yum install -y wget awscli jq

check_required_vars

# Install GNOME and set it as the desktop
log "--> Installing Linux GUI..."
yum -y groupinstall "GNOME Desktop" "Graphical Administration Tools"
# yum -y groupinstall "Server with GUI"

log "--> Setting default to graphical target..."
systemctl set-default graphical.target

if ! (rpm -q pcoip-agent-standard)
then
    install_pcoip_agent
else
    log "--> pcoip-agent-standard is already installed."
fi

update_firewall

log "--> Installation is complete!"

exit_and_restart
