# Copyright (c) 2021 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#!/bin/bash

######################
# Required Variables #
######################
# REQUIRED: You must fill in this value before running the script
PCOIP_REGISTRATION_CODE=""
# NOTE: Temp password for user "centos". please change upon first login.
TEMP_PASSWORD="SecuRe_pwd1"

######################
# Optional Variables #
######################
# You can use the default value set here or change it
AUTO_SHUTDOWN_IDLE_TIMER=240
CPU_POLLING_INTERVAL=15
ENABLE_AUTO_SHUTDOWN="true"
NVIDIA_DRIVER_URL="https://storage.googleapis.com/nvidia-drivers-us-public/GRID/GRID12.0/NVIDIA-Linux-x86_64-460.32.03-grid.run"
TERADICI_DOWNLOAD_TOKEN="yj39yHtgj68Uv2Qf"


LOG_FILE="/var/log/teradici/provisioning.log"

TERADICI_REPO_SETUP_SCRIPT_URL="https://dl.teradici.com/$TERADICI_DOWNLOAD_TOKEN/pcoip-agent/cfg/setup/bash.rpm.sh"

log() {
    local message="$1"
    echo "[$(date)] $message"
}

retry() {
    local retries=0
    local max_retries=3
    until [[ $retries -ge $max_retries ]]
    do  
    # Break if command succeeds, or log the retry if command fails.
        $@ && break || {

            log "--> Failed to run command. $@"
            log "--> Retries left... $(( $max_retries - $retries ))"
            ((retries++))
            sleep 10;
        }
    done

    if [[ $retries -eq $max_retries ]]
    then
        return 1
    fi
}

check_required_vars() {
    # Disable logging of secrets by wrapping the region with set +x and set -x
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

install_kernel_header() {
    log "--> Installing kernel headers and development packages..."
    yum install kernel-devel kernel-headers -y
    exitCode=$?
    if [[ $exitCode -ne 0 ]]; then
        log "--> ERROR: Failed to install kernel header."
        exit 1
    fi

    yum install gcc -y
    exitCode=$?
    if [[ $exitCode -ne 0 ]]; then
        log "--> ERROR: Failed to install gcc."
        exit 1
    fi
}

# Download installation script and run to instsall NVIDIA driver
install_gpu_driver() {
    # the first part to check if GPU is attached
    # NVIDIA VID = 10DE
    # Display class code = 0300
    # the second part to check if the NVIDIA driver is installed
    if [[ $(lspci -d '10de:*:0300' -s '.0' | wc -l) -gt 0 ]] && ! (modprobe --resolve-alias nvidia > /dev/null 2>&1)
    then
        log "--> Installing GPU driver..."

        local nvidia_driver_filename=$(basename $NVIDIA_DRIVER_URL)
        local gpu_installer="/root/$nvidia_driver_filename"

        log "--> Killing X server before installing driver..."
        systemctl stop gdm

        log "--> Downloading GPU driver $nvidia_driver_filename to $gpu_installer..."
        retry "curl -f -o $gpu_installer $NVIDIA_DRIVER_URL"
        chmod u+x "$gpu_installer"
        log "--> Running GPU driver installer..."

        # -s, --silent Run silently; no questions are asked and no output is printed,
        # This option implies '--ui=none --no-questions'.
        # -X, --run-nvidia-xconfig
        # -Z, --disable-nouveau
        # --sanity Perform basic sanity tests on an existing NVIDIA driver installation.
        # --uninstall Uninstall the currently installed NVIDIA driver.
        # using dkms cause kernel rebuild and installation failure
        if "$gpu_installer" -s -Z -X
        then
            log "--> GPU driver installed successfully."
        else
            log "--> ERROR: Failed to install GPU driver."
            exit 1
        fi
    fi
}

# Enable persistence mode
enable_persistence_mode() {
    # the first part to check if the NVIDIA driver is installed
    # the second part to check if persistence mode is enabled
    if (modprobe --resolve-alias nvidia > /dev/null 2>&1) && [[ $(nvidia-smi -q | awk '/Persistence Mode/{print $NF}') != "Enabled" ]]
    then
        log "--> Enabling persistence mode..."

        # tar -xvjf /usr/share/doc/NVIDIA_GLX-1.0/sample/nvidia-persistenced-init.tar.bz2 -C /tmp
        # chmod +x /tmp/nvidia-persistenced-init/install.sh
        # /tmp/nvidia-persistenced-init/install.sh
        # local exitCode=$?
        # rm -rf /tmp/nvidia-persistenced-init
        # if [[ $exitCode -ne 0 ]]

        # Enable persistence mode
        # based on document https://docs.nvidia.com/deploy/driver-persistence/index.html,
        # Persistence Daemon shall be used in future
        if (nvidia-smi -pm ENABLED)
        then
            log "--> Persistence mode enabled successfully."
        else
            log "--> ERROR: Failed to enable persistence mode."
            exit 1
        fi
    fi
}

install_pcoip_agent() {
    log "--> Getting Teradici PCoIP agent repo..."
    curl --retry 3 --retry-delay 5 -u "token:$TERADICI_DOWNLOAD_TOKEN" -1sLf $TERADICI_REPO_SETUP_SCRIPT_URL | bash
    if [ $? -ne 0 ]
    then
        log "--> ERROR: Failed to install PCoIP agent repo."
        exit 1
    fi
    log "--> PCoIP agent repo installed successfully."

    log "--> Installing USB dependencies..."
    retry "yum install -y usb-vhci"
    if [ $? -ne 0 ]; then
        log "--> Warning: Failed to install usb-vhci."
    fi
    log "--> usb-vhci successfully installed."

    log "--> Installing PCoIP graphics agent..."
    retry yum -y install pcoip-agent-graphics
    if [ $? -ne 0 ]; then
        log "--> ERROR: Failed to install PCoIP agent."
        exit 1
    fi
    log "--> PCoIP agent installed successfully."

    log "--> Registering PCoIP agent license..."
    n=0
    set +x
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
    set -x
    log "--> PCoIP agent registered successfully."
}

install_idle_shutdown() {
    log "--> Installing idle shutdown..."
    mkdir /tmp/idleShutdown

    retry wget "https://raw.githubusercontent.com/teradici/deploy/master/remote-workstations/new-agent-vm/Install-Idle-Shutdown.sh" -O /tmp/idleShutdown/Install-Idle-Shutdown-raw.sh

    awk '{ sub("\r$", ""); print }' /tmp/idleShutdown/Install-Idle-Shutdown-raw.sh > /tmp/idleShutdown/Install-Idle-Shutdown.sh && chmod +x /tmp/idleShutdown/Install-Idle-Shutdown.sh

    log "--> Setting auto shutdown idle timer to $AUTO_SHUTDOWN_IDLE_TIMER minutes..."
    INSTALL_OPTS="--idle-timer $AUTO_SHUTDOWN_IDLE_TIMER"
    if [[ "$ENABLE_AUTO_SHUTDOWN" = "false" ]]; then
        INSTALL_OPTS="$INSTALL_OPTS --disabled"
    fi

    retry /tmp/idleShutdown/Install-Idle-Shutdown.sh $INSTALL_OPTS

    exitCode=$?
    if [[ $exitCode -ne 0 ]]; then
        log "--> ERROR: Failed to install idle shutdown."
        exit 1
    fi

    if [[ $CPU_POLLING_INTERVAL -ne 15 ]]; then
        log "--> Setting CPU polling interval to $CPU_POLLING_INTERVAL minutes..."
        sed -i "s/OnUnitActiveSec=15min/OnUnitActiveSec=$${CPU_POLLING_INTERVAL}min/g" /etc/systemd/system/CAMIdleShutdown.timer.d/CAMIdleShutdown.conf
        systemctl daemon-reload
    fi
}

# A flag to indicate if this is run from reboot
RE_ENTER=0

if (rpm -q pcoip-agent-graphics); then
    exit
fi

if [[ ! -f "$LOG_FILE" ]]
then
    mkdir -p "$(dirname $LOG_FILE)"
    touch "$LOG_FILE"
    chmod +644 "$LOG_FILE"
else
    RE_ENTER=1
fi

log "$(date)"

# Print all executed commands to the terminal
set -x

# Redirect stdout and stderr to the log file
exec &>>$LOG_FILE

check_required_vars

if [[ $RE_ENTER -eq 0 ]]
then
    set +x
    # Add default user "centos" and give the user a password so a user can start 
    # a PCoIP session without having to first create password via SSH
    useradd centos
    echo centos:$TEMP_PASSWORD | chpasswd

    set -x
    yum -y update

    yum install -y wget

    # Install GNOME and set it as the desktop
    log "--> Installing Linux GUI..."
    yum -y groupinstall "GNOME Desktop" "Graphical Administration Tools"

    log "--> Setting default to graphical target..."
    systemctl set-default graphical.target

    exit_and_restart
else
    install_kernel_header

    install_gpu_driver

    enable_persistence_mode

    if (rpm -q pcoip-agent-graphics)
    then
        log "--> pcoip-agent-graphics is already installed."
    else
        install_pcoip_agent
    fi

    install_idle_shutdown

    log "--> Installation is complete!"

    exit_and_restart
fi