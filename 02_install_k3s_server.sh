#!/usr/bin/env bash
# Run this ONLY on the control node.
# Disables Traefik (we don't need it) and the built-in ServiceLB
# (we're using MetalLB instead) to keep the cluster minimal.
set -euo pipefail

curl -sfL https://get.k3s.io | sh -s - server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644

echo ""
echo "==> k3s server installed."
echo "==> Node token (needed by workers):"
cat /var/lib/rancher/k3s/server/node-token

echo ""
echo "==> Your control node IP(s):"
hostname -I

echo ""
echo "==> Kubeconfig is at /etc/rancher/k3s/k3s.yaml"
echo "    To use kubectl from this machine directly:"
echo "    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"