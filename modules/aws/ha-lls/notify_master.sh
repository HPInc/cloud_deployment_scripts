#!/usr/bin/env bash

LOG_FILE="/var/log/teradici/keepalived-notify-master.log"
METADATA="http://169.254.169.254/latest/meta-data"

set -x

if [[ ! -f "$LOG_FILE" ]]
then
    mkdir -p "$(dirname $LOG_FILE)"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
fi

exec &>> $LOG_FILE

echo "[$(date)] Running $0 as $(whoami)..."

MAC=$(curl -s ${METADATA}/mac)
INF_ID=$(curl -s ${METADATA}/network/interfaces/macs/${MAC}/interface-id)

aws ec2 assign-private-ip-addresses --allow-reassignment --network-interface-id ${INF_ID} --private-ip-addresses ${vip}
