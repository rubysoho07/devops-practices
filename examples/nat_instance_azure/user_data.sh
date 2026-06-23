#!/bin/bash
# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Install and configure iptables
dnf install -y iptables-services
systemctl enable --now iptables

# NAT masquerade on the primary interface
PRIMARY_IF=$(ip route | awk '/default/ {print $5; exit}')
iptables -t nat -A POSTROUTING -o "$PRIMARY_IF" -j MASQUERADE
iptables -A FORWARD -i "$PRIMARY_IF" -j ACCEPT
iptables -A FORWARD -o "$PRIMARY_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT

# Persist rules
service iptables save
