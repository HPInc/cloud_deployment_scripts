# Copyright Teradici Corporation 2021;  © Copyright 2022-2024 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#!/bin/bash

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
AUTO_LOGOFF_CPU_UTILIZATION=20
AUTO_LOGOFF_ENABLE=true
AUTO_LOGOFF_MINUTES_IDLE_BEFORE_LOGOFF=20
AUTO_LOGOFF_POLLING_INTERVAL_MINUTES=5
TERADICI_DOWNLOAD_TOKEN="yj39yHtgj68Uv2Qf"


LOG_FILE="/var/log/teradici/provisioning.log"

TERADICI_REPO_SETUP_SCRIPT_URL="https://dl.anyware.hp.com/$TERADICI_DOWNLOAD_TOKEN/pcoip-agent/cfg/setup/bash.rpm.sh"

log() {
    local message="$1"
    echo "[$(date)] $message"
}

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
    retry 3 `# 3 retries` \
          5 `# 5s interval` \
          "yum install -y usb-vhci" \
          "--> Warning: Failed to install usb-vhci."
    if [ $? -ne 0 ]; then
        log "--> Warning: Failed to install usb-vhci."
    fi
    log "--> usb-vhci successfully installed."

    log "--> Installing PCoIP standard agent..."
    retry 3 `# 3 retries` \
          5 `# 5s interval` \
          "yum -y install pcoip-agent-standard" \
          "--> ERROR: Failed to download PCoIP agent."
    if [ $? -ne 0 ]; then
        log "--> ERROR: Failed to install PCoIP agent."
        exit 1
    fi
    log "--> PCoIP agent installed successfully."
}

register_pcoip_agent() {
    log "--> Registering PCoIP agent license..."

    retry   10 `# 10 retries` \
            10 `# 10s interval` \
            "/usr/sbin/pcoip-register-host --registration-code="$PCOIP_REGISTRATION_CODE" && break" \
            "--> ERROR: Failed to register PCoIP agent."
    
    if [ $? -ne 0 ]; then
        exit 1
    fi
    log "--> PCoIP agent registered successfully."
}

install_auto_logoff() {
    # Auto logoff tool terminates a user session after the PCoIP session has been terminated. Please see the documentation for more details:
    # https://www.teradici.com/web-help/anyware_manager/22.09/admin_console/workstation_pools/#auto-log-off-service

    log "--> Installing PCoIP agent auto-logoff..."
    retry   3 `# 3 retries` \
            5 `# 5s interval` \
            "yum install -y pcoip-agent-autologoff" \
            "--> ERROR: Failed to download PCoIP agent auto-logoff."

    log "--> Setting Minumim Idle time to $AUTO_LOGOFF_MINUTES_IDLE_BEFORE_LOGOFF minutes..."
    sed -i "s/Environment=\"MinutesIdleBeforeLogOff=\(.*\)\"/Environment=\"MinutesIdleBeforeLogOff=$AUTO_LOGOFF_MINUTES_IDLE_BEFORE_LOGOFF\"/g" /etc/systemd/system/pcoip-agent-autologoff.service.d/override.conf

    log "--> Setting CPU Utilization limit to $AUTO_LOGOFF_CPU_UTILIZATION%..."
    sed -i "s/Environment=\"CPUUtilizationLimit=\(.*\)\"/Environment=\"CPUUtilizationLimit=$AUTO_LOGOFF_CPU_UTILIZATION\"/g" /etc/systemd/system/pcoip-agent-autologoff.service.d/override.conf

    log "--> Setting CPU polling interval to $AUTO_LOGOFF_POLLING_INTERVAL_MINUTES minutes..."
    sed -i "s/OnUnitActiveSec=\(.*\)min/OnUnitActiveSec=$${AUTO_LOGOFF_POLLING_INTERVAL_MINUTES}min/g" /etc/systemd/system/pcoip-agent-autologoff.timer.d/override.conf

    /opt/teradici/pcoip-agent-autologoff/pcoip-agent-autologoff-mgmt --enable
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

# Print all executed commands to the terminal
set -x

# Redirect stdout and stderr to the log file
exec &>>$LOG_FILE

log "$(date) Running $0 as $(whoami)..."

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

check_required_vars

yum -y update

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

set +x
if [[ -z "$PCOIP_REGISTRATION_CODE" ]]
then
    log "--> No PCoIP Registration Code provided. Skipping PCoIP agent registration..."
else
    register_pcoip_agent
fi
set -x

if [[ "$AUTO_LOGOFF_ENABLE" == "true" ]]
then
    install_auto_logoff
fi

log "--> Installation is complete!"

exit_and_restart
