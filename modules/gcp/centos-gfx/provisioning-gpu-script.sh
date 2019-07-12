# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#!/bin/bash

NVIDIA_GRID_VERSION=7.1
NVIDIA_DRIVER_VERSION=410.92

log() {
    local message="$1"
    echo "[$(date)] ${message}" | tee -a "$INST_LOG_FILE"
}

exit_and_restart()
{
    log "--> Rebooting"
    (sleep 1; reboot -p) &
    exit
}

update_kernel_dkms()
{
    if ! (rpm -q dkms > /dev/null 2>&1)
    then

        log "--> Installing kernel devel header"
        yum -y install "kernel-devel-uname-r == $(uname -r)"
        # ln -s /usr/src/linux-headers-$(uname -r)  /lib/modules/$(uname -r)/build
        ln -s /usr/src/kernels-"$(uname -r)"  /lib/modules/"$(uname -r)"/build

        log "--> Downloading kernel dkms module"
        rpm -Uvh --quiet https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

        log "--> Updating kernel dkms module"
        yum -y install epel-release
        if (yum -y install dkms)
        then
            log "--> DKMS is installed successfully"
        else
            log "--> Failed to update DKMS"
        fi
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
        log "--> Start to install gpu driver ..."
        local gpu_installer="/tmp/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}-grid.run"
        log "--> Downloading gpu driver ..."
        wget --retry-connrefused --tries=3 --waitretry=5 -O "$gpu_installer" https://storage.googleapis.com/nvidia-drivers-us-public/GRID/GRID${NVIDIA_GRID_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}-grid.run
        chmod u+x "$gpu_installer"
        log "--> Running gpu driver installer ..."

        # -s, --silent Run silently; no questions are asked and no output is printed,
        # This option implies '--ui=none --no-questions'.
        # -X, --run-nvidia-xconfig
        # -Z, --disable-nouveau
        # --sanity Perform basic sanity tests on an existing NVIDIA driver installation.
        # --uninstall Uninstall the currently installed NVIDIA driver.
        # --dkms
        #     nvidia-installer can optionally register the NVIDIA kernel
        #     module sources, if installed, with DKMS, then build and
        #     install a kernel module using the DKMS-registered sources.
        #     This will allow the DKMS infrastructure to automatically
        #     build a new kernel module when changing kernels.  During
        #     installation, if DKMS is detected, nvidia-installer will
        #     ask the user if they wish to register the module with DKMS;
        #     the default response is 'no'.  This option will bypass the
        #     detection of DKMS, and cause the installer to attempt a
        #     DKMS-based installation regardless of whether DKMS is
        #     present.
        # using dkms cause kernel rebuild and installation failure
        #if ("$gpu_installer" -s --dkms)
        if "$gpu_installer" -s -Z -X --dkms
        then
            log "--> GPU driver is installed successfully"
        else
            log "--> Failed to install gpu driver"
            # exit 1
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
            log "--> Persistence mode is enabled successfully"
        else
            log "--> Failed to enable persistence mode."
            # exit 1
        fi
    fi
}

install_pcoip_agent() {
    if ! (rpm -q pcoip-agent-graphics)
    then
        log "--> Start to install pcoip agent ..."
        # Get the Teradici pubkey
        log "--> Get Teradici pubkey"
        rpm --import https://downloads.teradici.com/rhel/teradici.pub.gpg

        # Get pcoip repo
        log "--> Get Teradici pcoip agent repo"
        wget --retry-connrefused --tries=3 --waitretry=5 -O /etc/yum.repos.d/pcoip.repo https://downloads.teradici.com/rhel/pcoip.repo

        log "--> Install pcoip agent ..."
        yum -y install pcoip-agent-graphics

        # Register the pcoip agent
        log "--> Register pcoip agent license ..."
        /usr/sbin/pcoip-register-host --registration-code="$REGISTRATION_CODE"
        log "--> Pcoip agent is installed successfully"
    fi
}

# Join domain
join_domain()
{
    local dns_record_file="dns_record"
    if [[ ! -f "$dns_record_file" ]]
    then
        log "--> DOMAIN NAME: $DOMAIN_NAME"
        log "--> USERNAME: $USERNAME"
        log "--> DOMAIN CONTROLLER: $IP_ADDRESS"

        VM_NAME=$(hostname)

        # Wait for AD service account to be set up
        yum -y install openldap-clients
        log "--> Wait for AD account $USERNAME@$DOMAIN_NAME to be available"
        until ldapwhoami -H ldap://$IP_ADDRESS -D $USERNAME@$DOMAIN_NAME -w $PASSWORD -o nettimeout=1 > /dev/null 2>&1
        do
            log "$USERNAME@$DOMAIN_NAME not available yet, retrying in 10 seconds..."
            sleep 10
        done

        # Join domain
        log "--> Install required packages to join domain"
        yum -y install sssd realmd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation openldap-clients policycoreutils-python

        log "--> Restarting messagebus service"
        if ! (systemctl restart messagebus)
        then
            log "--> Failed to restart messagebus service"
            return 106
        fi

        log "--> Enable and start sssd service"
        if ! (systemctl enable sssd --now)
        then
            log "Failed to start sssd service"
            return 106
        fi

        log "--> Joining the domain"
        if [[ -n "$OU" ]]
        then
            echo "$PASSWORD" | realm join --user="$USERNAME" --computer-ou="$OU" "$DOMAIN_NAME" >&2
        else
            echo "$PASSWORD" | realm join --user="$USERNAME" "$DOMAIN_NAME" >&2
        fi
        exitCode=$?
        if [[ $exitCode -eq 0 ]]
        then
            log "--> Joined Domain '$DOMAIN_NAME' and OU '$OU'"
        else
            log "--> Failed to join Domain '$DOMAIN_NAME' and OU '$OU'"
            return 106
        fi

        log "--> Configuring settings"
        sed -i '$ a\dyndns_update = True\ndyndns_ttl = 3600\ndyndns_refresh_interval = 43200\ndyndns_update_ptr = True\nldap_user_principal = nosuchattribute' /etc/sssd/sssd.conf
        sed -c -i "s/\\(use_fully_qualified_names *= *\\).*/\\1False/" /etc/sssd/sssd.conf
        sed -c -i "s/\\(fallback_homedir *= *\\).*/\\1\\/home\\/%u/" /etc/sssd/sssd.conf
        domainname "$VM_NAME.$DOMAIN_NAME"
        echo "%$DOMAIN_NAME\\\\Domain\\ Admins ALL=(ALL) ALL" > /etc/sudoers.d/sudoers

        log "--> Registering with DNS"
        DOMAIN_UPPER=$(echo "$DOMAIN_NAME" | tr '[:lower:]' '[:upper:]')
        IP_ADDRESS=$(hostname -I | grep -Eo '10.([0-9]*\.){2}[0-9]*')
        echo "$PASSWORD" | kinit "$USERNAME"@"$DOMAIN_UPPER"
        touch "$dns_record_file"
        echo "update add $VM_NAME.$DOMAIN_NAME 600 a $IP_ADDRESS" > "$dns_record_file"
        echo "send" >> "$dns_record_file"
        nsupdate -g "$dns_record_file"
    fi
}

# ------------------------------------------------------------
# start from here
# ------------------------------------------------------------
# A flag to indicate if this is run from reboot
RE_ENTER=0

INST_LOG_FILE="/var/log/teradici/agent/install.log"
if [[ ! -f "$INST_LOG_FILE" ]]
then
    mkdir -p "$(dirname ${INST_LOG_FILE})"
    touch "$INST_LOG_FILE"
    chmod +644 "$INST_LOG_FILE"
else
    RE_ENTER=1
fi

log "$(date)"

if [[ $RE_ENTER -eq 0 ]]
then
    # yum -y update

    yum install -y wget

    # Install GNOME and set it as the desktop
    log "--> Install Linux GUI ..."
    yum -y groupinstall "GNOME Desktop" "Graphical Administration Tools"
    # yum -y groupinstall "Server with GUI"

    log "--> Set default to graphical target"
    systemctl set-default graphical.target

    join_domain

    update_kernel_dkms

    exit_and_restart
else
    yum install -y pciutils

    install_gpu_driver

    enable_persistence_mode

    install_pcoip_agent

    log "--> Installation is completed !!!"

    exit_and_restart
fi