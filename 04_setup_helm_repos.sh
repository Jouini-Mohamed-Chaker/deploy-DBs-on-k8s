#!/usr/bin/env bash
# Run this on the control node, after kubectl get nodes shows all 4 nodes Ready.
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