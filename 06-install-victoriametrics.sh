#!/usr/bin/env bash
# Run this on the control node after 05-install-cockroachdb.sh.
# Installs single-node VictoriaMetrics using
# manifests/victoria-metrics-values.yaml.
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

helm upgrade --install victoria-metrics vm/victoria-metrics-single \
  -f "${REPO_ROOT}/manifests/victoria-metrics-values.yaml" \
  -n default

echo ""
echo "==> Waiting for VictoriaMetrics pod to become Ready..."
kubectl rollout status deployment/victoria-metrics-single-server -n default --timeout=180s || \
  kubectl rollout status statefulset/victoria-metrics-single-server -n default --timeout=180s

echo ""
kubectl get pods -l app.kubernetes.io/name=victoria-metrics-single -n default