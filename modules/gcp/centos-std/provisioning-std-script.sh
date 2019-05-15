#!/bin/bash

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

install_pcoip_agent() {
    if ! (rpm -q pcoip-agent-standard)
    then
        log "--> Start to install pcoip agent ..."
        # Get the Teradici pubkey
        log "--> Get Teradici pubkey"
        rpm --import https://downloads.teradici.com/rhel/teradici.pub.gpg

        # Get pcoip repo
        log "--> Get Teradici pcoip agent repo"
        wget --retry-connrefused --tries=3 --waitretry=5 -O /etc/yum.repos.d/pcoip.repo https://downloads.teradici.com/rhel/pcoip.repo

        log "--> Install pcoip agent ..."
        yum -y install pcoip-agent-standard

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

        VM_NAME=$(hostname)

        # Wait for the Domain Controller to come up
        log "--> Trying to reach the Domain Controller @ $IP_ADDRESS"
        until ping -c1 $IP_ADDRESS > /dev/null 2>&1
        do
            log "Unable to reach the Domain Controller, retrying in 10 seconds..."
            sleep 10
        done

        # Wait for AD service account to be set up
        yum -y install openldap-clients
        log "--> Wait for AD account $USERNAME@$DOMAIN_NAME to be available"
        until ldapwhoami -H ldap://$DOMAIN_NAME -D $USERNAME@$DOMAIN_NAME -w $PASSWORD > /dev/null 2>&1
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

INST_LOG_FILE="/var/log/teradici/agent/install.log"

# Don't run if PCoIP Agent already installed
if (rpm -q pcoip-agent-standard); then
    exit
fi

log "$(date)"

# yum -y update

yum install -y wget

# Install GNOME and set it as the desktop
log "--> Install Linux GUI ..."
yum -y groupinstall "GNOME Desktop" "Graphical Administration Tools"
# yum -y groupinstall "Server with GUI"

log "--> Set default to graphical target"
systemctl set-default graphical.target

# Update resolv.conf for domain
sed -i "0,/nameserver/s//search $DOMAIN_NAME\nnameserver $IP_ADDRESS\nnameserver/" /etc/resolv.conf
echo 'PEERDNS=no' >> /etc/sysconfig/network-scripts/ifcfg-eth0
chattr +i /etc/resolv.conf

join_domain

install_pcoip_agent

log "--> Installation is completed !!!"

exit_and_restart