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

VM_SVC="$(kubectl get svc -n default \
  -l "app.kubernetes.io/instance=victoria-metrics,app.kubernetes.io/component=server" \
  -o jsonpath='{.items[0].metadata.name}')"

echo "==> Patching ${VM_SVC} to NodePort"
kubectl patch svc "${VM_SVC}" -n default -p '{"spec": {"type": "NodePort"}}'

echo ""
echo "==> Assigned NodePorts:"
kubectl get svc cockroachdb-public "${VM_SVC}" -n default

echo ""
echo "==> Reach them at http(s)://<any-node-ip>:<port-shown-above>"