#!/usr/bin/env bash
# Run this on the control node as your normal user (NOT with sudo).
# k3s writes its kubeconfig as world-readable by default, so no sudo
# is needed here - and using sudo would install Helm repos into root's
# config instead of yours, causing "repo not found" errors on every
# later `helm install` you run as yourself.
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

if ! command -v helm >/dev/null; then
  echo "==> Installing Helm"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "==> Adding chart repos"
helm repo add cockroachdb https://charts.cockroachdb.com/
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm repo update

echo "==> Repos ready:"
helm repo list