#!/bin/bash

# Copyright (c) 2021 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

######################
# Required Variables #
######################
# REQUIRED: You must fill in this value before running the script
PCOIP_REGISTRATION_CODE=""

######################
# Optional Variables #
######################
# NOTE: Fill both USERNAME and TEMP_PASSWORD to create login credential, 
# otherwise please SSH into workstation to add user and set password.
# Please change password upon first login.
USERNAME=""
TEMP_PASSWORD=""
# You can use the default value set here or change it
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
    retry   3 `# 3 retries` \
            5 `# 5s interval` \
            "yum install -y usb-vhci" \
            "--> Warning: Failed to install usb-vhci."

    log "--> Installing PCoIP standard agent..."
    retry   3 `# 3 retries` \
            5 `# 5s interval` \
            "yum -y install pcoip-agent-standard" \
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

# Add a user and give the user a password so a user can start 
# a PCoIP session without having to first create password via SSH
# if USERNAME and TEMP_PASSWORD were provided
set +x
if [[ "$TEMP_PASSWORD" && "$USERNAME" ]]
then
    useradd $USERNAME
    echo $USERNAME:$TEMP_PASSWORD | chpasswd
    log "--> User and TEMP_PASSWORD has been set."
else
    log "--> USERNAME or TEMP_PASSWORD not provided. Skip creating user..."
fi
set -x

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

if (rpm -q pcoip-agent-standard)
then
    log "--> pcoip-agent-standard is already installed."
else
    install_pcoip_agent
fi

update_firewall

log "--> Installation is complete!"

exit_and_restart
