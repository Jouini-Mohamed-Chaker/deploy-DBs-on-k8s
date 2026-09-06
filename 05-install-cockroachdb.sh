#!/usr/bin/env bash
# Run this on the control node after 04-setup-helm-repos.sh.
# Installs the 3-replica CockroachDB StatefulSet using
# manifests/cockroachdb-values.yaml.
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

helm upgrade --install cockroachdb cockroachdb/cockroachdb \
  -f "${REPO_ROOT}/manifests/cockroachdb-values.yaml" \
  -n default

echo ""
echo "==> Waiting for CockroachDB pods to become Ready (this can take a couple minutes)..."
kubectl rollout status statefulset/cockroachdb -n default --timeout=300s || true

echo ""
kubectl get pods -l app.kubernetes.io/name=cockroachdb -n default