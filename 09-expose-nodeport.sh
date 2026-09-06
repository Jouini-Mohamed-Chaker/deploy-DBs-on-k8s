#!/usr/bin/env bash
# Run this on the control node, after CockroachDB and VictoriaMetrics
# are installed. Exposes both via NodePort (no MetalLB needed) so they
# are reachable at http(s)://<any-node-ip>:<nodeport>.
#
# If you only need access from the control node itself, skip this
# entirely and use `kubectl port-forward` instead - it needs no service
# changes at all.
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "==> Patching cockroachdb-public to NodePort"
kubectl patch svc cockroachdb-public -n default -p '{"spec": {"type": "NodePort"}}'

echo "==> Exposing VictoriaMetrics as NodePort"
if ! kubectl get svc vm-external -n default >/dev/null 2>&1; then
  kubectl expose deployment victoria-metrics-single-server \
    --type=NodePort --port=8428 --name=vm-external -n default
else
  echo "    vm-external already exists, skipping"
fi

echo ""
echo "==> Assigned NodePorts:"
kubectl get svc cockroachdb-public vm-external -n default

echo ""
echo "==> Reach them at http(s)://<any-node-ip>:<port-shown-above>"