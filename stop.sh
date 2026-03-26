#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
  echo "Exec like root please" >&2
  exit 1
fi

# Clean symlinks in netnamespaces
find -L /var/run/netns -type l -delete

# Destroy wireless interfaces and stop services
modprobe mac80211_hwsim -r
docker-compose down