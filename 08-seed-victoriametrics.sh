#!/usr/bin/env bash
# Run this from the control node once VictoriaMetrics is deployed.
# Imports metrics from a file in Prometheus exposition format
# into VictoriaMetrics via its /api/v1/import/prometheus endpoint.
#
# Usage: ./05-seed-victoriametrics.sh <path-to-metrics-file>
#
# Example metrics file line format:
#   http_requests_total{method="GET",code="200"} 1027 1717000000000
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <path-to-metrics-file>"
  exit 1
fi

METRICS_FILE="$1"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "==> Port-forwarding VictoriaMetrics (Ctrl+C won't stop the import, it runs in background)"
kubectl port-forward svc/victoria-metrics-single-server 8428:8428 -n default &
PF_PID=$!
sleep 3

echo "==> Importing ${METRICS_FILE}"
curl -v --data-binary "@${METRICS_FILE}" \
  http://localhost:8428/api/v1/import/prometheus

kill "$PF_PID"
echo "==> Done."