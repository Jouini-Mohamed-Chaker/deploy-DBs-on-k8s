#!/usr/bin/env bash
# Run this on the control node after 05-install-cockroachdb.sh, and any
# time you edit manifests/schema-and-seed.sql and want to re-apply it.
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Creating/updating ConfigMap from schema-and-seed.sql"
kubectl create configmap cockroachdb-seed \
  --from-file=seed.sql="${REPO_ROOT}/manifests/schema-and-seed.sql" \
  -n default \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Removing any previous seed Job (Jobs don't re-run automatically)"
kubectl delete job cockroachdb-seed -n default --ignore-not-found

echo "==> Applying seed Job"
kubectl apply -f "${REPO_ROOT}/manifests/cockroachdb-seed-job.yaml"

echo "==> Waiting for seed Job to complete..."
kubectl wait --for=condition=complete job/cockroachdb-seed -n default --timeout=120s

echo ""
echo "==> Seed Job logs:"
kubectl logs job/cockroachdb-seed -n default