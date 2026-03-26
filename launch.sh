#!/bin/bash

WLAN0="wlan0"
WLAN1="wlan1"
WLAN2="wlan2"
WLAN3="wlan3"
WLAN4="wlan4"
WLAN5="wlan5"

if [[ "$EUID" -ne 0 ]]; then
  echo "Exec like root please" >&2
  exit 1
fi

# Build and launch services
docker-compose build
docker-compose up -d
sleep 20
# docker-compose ps

# Assign wireless interfaces to containers
# Create virtual wireless interfaces
modprobe mac80211_hwsim radios=6
echo "Wireless interfaces names:"
echo "$(iw dev | awk '/Interface/ {print $2}')"
echo "If not wlan0, wlan1, wlan2, wlan3, wlan4, wlan5 stop services and change this names in hostapd.conf, launch.sh and stop.sh" 
sleep 2

# Define natworks namespaces
mkdir -p /var/run/netns

# Search phy interfaces of each wireless interface
WLAN0_PHY=$(cat /sys/class/net/"$WLAN0"/phy80211/name)
WLAN1_PHY=$(cat /sys/class/net/"$WLAN1"/phy80211/name)
WLAN2_PHY=$(cat /sys/class/net/"$WLAN2"/phy80211/name)
WLAN3_PHY=$(cat /sys/class/net/"$WLAN3"/phy80211/name)
WLAN4_PHY=$(cat /sys/class/net/"$WLAN4"/phy80211/name)
WLAN5_PHY=$(cat /sys/class/net/"$WLAN5"/phy80211/name)

# Search PID of each docker container in WLAN
AP_PID=$(docker inspect -f '{{.State.Pid}}' ap)
CLIENT1_PID=$(docker inspect -f '{{.State.Pid}}' client1)
CLIENT2_PID=$(docker inspect -f '{{.State.Pid}}' client2)
CLIENT3_PID=$(docker inspect -f '{{.State.Pid}}' client3)
ATTACKER_PID=$(docker inspect -f '{{.State.Pid}}' attacker1)

# Associate each wireless interface to pid container network namespace
ln -s /proc/"$AP_PID"/ns/net /var/run/netns/"$AP_PID"
ln -s /proc/"$CLIENT1_PID"/ns/net /var/run/netns/"$CLIENT1_PID"
ln -s /proc/"$CLIENT2_PID"/ns/net /var/run/netns/"$CLIENT2_PID"
ln -s /proc/"$CLIENT3_PID"/ns/net /var/run/netns/"$CLIENT3_PID"
ln -s /proc/"$ATTACKER_PID"/ns/net /var/run/netns/"$ATTACKER_PID"
iw phy "$WLAN0_PHY" set netns "$AP_PID"
iw phy "$WLAN1_PHY" set netns "$CLIENT1_PID"
iw phy "$WLAN2_PHY" set netns "$CLIENT2_PID"
iw phy "$WLAN3_PHY" set netns "$CLIENT3_PID"
iw phy "$WLAN4_PHY" set netns "$ATTACKER_PID"
iw phy "$WLAN5_PHY" set netns "$ATTACKER_PID"
    
# Assign an IP to the wifi interface
ip netns exec "$AP_PID" ip addr flush dev "$WLAN0"
ip netns exec "$CLIENT1_PID" ip addr flush dev "$WLAN1"
ip netns exec "$CLIENT2_PID" ip addr flush dev "$WLAN2"
ip netns exec "$CLIENT3_PID" ip addr flush dev "$WLAN3"
ip netns exec "$ATTACKER_PID" ip addr flush dev "$WLAN4"
ip netns exec "$ATTACKER_PID" ip addr flush dev "$WLAN5"
ip netns exec "$AP_PID" ip link set "$WLAN0" up
ip netns exec "$CLIENT1_PID" ip link set "$WLAN1" up
ip netns exec "$CLIENT2_PID" ip link set "$WLAN2" up
ip netns exec "$CLIENT3_PID" ip link set "$WLAN3" up
ip netns exec "$ATTACKER_PID" ip link set "$WLAN4" up
ip netns exec "$ATTACKER_PID" ip link set "$WLAN5" up

# Assign IP to AP device only (rest use DHCP when connect to AP)
ip netns exec "$AP_PID" ip addr add 10.5.2.129/26 dev "$WLAN0"

# Init access point
echo "AP up"
docker-compose exec access-point-1 /ap/start.sh
sleep 2

# Init and connect clients
echo "WLAN clients up"
docker-compose exec client-1 /client/start.sh "$WLAN1"
docker-compose exec client-2 /client/start.sh "$WLAN2"
docker-compose exec client-3 /client/start.sh "$WLAN3"

# Init attacker (but not connect)
echo "Attacker up"
docker-compose exec attacker-1 /attacker/start.sh

echo "Now, you can practice ;)"
echo "Don't forget stop lab when finish"