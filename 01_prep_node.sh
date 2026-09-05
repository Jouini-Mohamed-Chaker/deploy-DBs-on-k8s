#!/usr/bin/env bash
# Run this on ALL 4 VMs (control + 3 workers) as root, before installing k3s.
set -euo pipefail

echo "==> Disabling swap"
swapoff -a
sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab

echo "==> Loading required kernel modules"
cat <<EOF | tee /etc/modules-load.d/k3s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "==> Setting required sysctls"
cat <<EOF | tee /etc/sysctl.d/99-k3s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "==> Installing base tools"
if command -v apt-get >/dev/null; then
  apt-get update -y
  apt-get install -y curl open-iscsi
elif command -v yum >/dev/null; then
  yum install -y curl iscsi-initiator-utils
fi

echo "==> Node prep complete. Reboot recommended but not required."