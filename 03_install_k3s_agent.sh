#!/usr/bin/env bash
# Run this on EACH of the 3 worker VMs.
# Usage: ./03-install-k3s-agent.sh <control-node-ip> <node-token>
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <control-node-ip> <node-token>"
  exit 1
fi

SERVER_IP="$1"
TOKEN="$2"

curl -sfL https://get.k3s.io | \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="${TOKEN}" \
  sh -

echo "==> k3s agent installed and joined ${SERVER_IP}."
echo "==> Verify from the control node with: kubectl get nodes"