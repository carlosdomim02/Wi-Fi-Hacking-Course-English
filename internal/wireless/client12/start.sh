#!/bin/bash

# route add default gw 10.5.2.129

# Clean old executions
pkill wpa_supplicant 
sleep 1

# Check if interface is passed
if [[ -z "$1" ]]; then
    echo "Usage: command <wirelless-interface>"
    exit 1
fi
IFACE="$1"

# Check if interface exists 
if ! ip link show "$IFACE" > /dev/null 2>&1; then
    echo "Error: '$IFACE' not exists."
    exit 1
fi

# Associate external IP web service to domain
echo "#10.5.0.20      carlos.web.com" >> /etc/hosts

# Connect to WLAN
wpa_supplicant -i "$IFACE" -c wpa_supplicant_"$IFACE".conf -B
sleep 2
dhclient "$IFACE"
