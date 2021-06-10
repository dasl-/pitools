#!/usr/bin/env bash

# Credit for this script: 
# https://willhaley.com/blog/raspberry-pi-wifi-ethernet-bridge/
# 
# The goal is to connect a non-WiFi computer to a WiFI network via a Raspberry Pi. We will 
# use a Raspberry Pi 4 Model B as a bridge between the non-WiFi computer and the WiFi network. 
# The Raspberry Pi connects to WiFi and shares its connection with other computers using Ethernet.
# 
# Option 1 - Same Subnet
# This option is complex, but provides a more seamless experience. Bridged clients connected to 
# the Pi should behave as if they were connected directly to the upstream network.

set -e

[ $EUID -ne 0 ] && echo "run as root" >&2 && exit 1

##########################################################
# You should not need to update anything below this line #
##########################################################

# parprouted  - Proxy ARP IP bridging daemon
# dhcp-helper - DHCP/BOOTP relay agent

apt update && apt install -y parprouted dhcp-helper

systemctl stop dhcp-helper
systemctl enable dhcp-helper

# Enable ipv4 forwarding.
sed -i'' s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/ /etc/sysctl.conf

# Service configuration for standard WiFi connection. Connectivity will
# be lost if the username and password are incorrect.
systemctl restart wpa_supplicant.service

# Enable IP forwarding for wlan0 if it's not already enabled.
grep '^option ip-forwarding 1$' /etc/dhcpcd.conf || printf "option ip-forwarding 1\n" >> /etc/dhcpcd.conf

# Disable dhcpcd control of eth0.
grep '^denyinterfaces eth0$' /etc/dhcpcd.conf || printf "denyinterfaces eth0\n" >> /etc/dhcpcd.conf

# Configure dhcp-helper.
cat > /etc/default/dhcp-helper <<EOF
DHCPHELPER_OPTS="-b wlan0"
EOF

# Enable avahi reflector if it's not already enabled.
sed -i'' 's/#enable-reflector=no/enable-reflector=yes/' /etc/avahi/avahi-daemon.conf
grep '^enable-reflector=yes$' /etc/avahi/avahi-daemon.conf || {
  printf "something went wrong...\n\n"
  printf "Manually set 'enable-reflector=yes in /etc/avahi/avahi-daemon.conf'\n"
}

# I have to admit, I do not understand ARP and IP forwarding enough to explain
# exactly what is happening here. I am building off the work of others. In short
# this is a service to forward traffic from WiFi to Ethernet.
cat <<'EOF' >/usr/lib/systemd/system/parprouted.service
[Unit]
Description=proxy arp routing service
Documentation=https://raspberrypi.stackexchange.com/q/88954/79866
Requires=sys-subsystem-net-devices-wlan0.device dhcpcd.service
After=sys-subsystem-net-devices-wlan0.device dhcpcd.service

[Service]
Type=forking
# Restart until wlan0 gained carrier
Restart=on-failure
RestartSec=5
TimeoutStartSec=30
# clone the dhcp-allocated IP to eth0 so dhcp-helper will relay for the correct subnet
ExecStartPre=/bin/bash -c '/sbin/ip addr add $(/sbin/ip -4 -br addr show wlan0 | /bin/grep -Po "\\d+\\.\\d+\\.\\d+\\.\\d+")/32 dev eth0'
ExecStartPre=/sbin/ip link set dev eth0 up
ExecStartPre=/sbin/ip link set wlan0 promisc on
ExecStart=-/usr/sbin/parprouted eth0 wlan0
ExecStopPost=/sbin/ip link set wlan0 promisc off
ExecStopPost=/sbin/ip link set dev eth0 down
ExecStopPost=/bin/bash -c '/sbin/ip addr del $(/sbin/ip -4 -br addr show wlan0 | /bin/grep -Po "\\d+\\.\\d+\\.\\d+\\.\\d+")/32 dev eth0'

[Install]
WantedBy=wpa_supplicant.service
EOF

systemctl daemon-reload
systemctl enable parprouted
systemctl start parprouted dhcp-helper
