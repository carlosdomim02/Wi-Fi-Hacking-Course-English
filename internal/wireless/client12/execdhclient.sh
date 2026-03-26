#!/bin/bash
IFACE="$1"
ACTION="$2"

if [ "$ACTION" = "CONNECTED" ]; then
    dhclient -r "$IFACE"
    dhclient "$IFACE"
fi
