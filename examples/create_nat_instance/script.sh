#!/bin/bash
dnf install -y iptables-services
systemctl enable --now iptables-services

# Kernel Setting
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# iptables rule
iptables -t nat -A POSTROUTING -o ens5 -s 0.0.0.0/0 -j MASQUERADE
iptables -F FORWARD
service iptables save