#!/usr/bin/env bash
# Run this any time on the control node to get a full snapshot of the
# cluster and both databases - nodes, pods, services, CockroachDB
# schema/row counts, and VictoriaMetrics health.
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

hr() { printf '\n%s\n' "──────────────────────────────────────────────────────"; }

hr; echo "NODES"; hr
kubectl get nodes -o wide

hr; echo "PODS (all namespaces)"; hr
kubectl get pods -A -o wide

hr; echo "SERVICES (default namespace)"; hr
kubectl get svc -n default

hr; echo "PERSISTENT VOLUME CLAIMS"; hr
kubectl get pvc -n default

hr; echo "HELM RELEASES"; hr
helm list -n default

hr; echo "COCKROACHDB: cluster status"; hr
kubectl exec -it cockroachdb-0 -n default -- \
  ./cockroach node status --insecure --host=cockroachdb-public 2>/dev/null || \
  echo "cockroachdb-0 not reachable yet"

hr; echo "COCKROACHDB: databases"; hr
kubectl exec -it cockroachdb-0 -n default -- \
  ./cockroach sql --insecure --host=cockroachdb-public -e "SHOW DATABASES;" 2>/dev/null || \
  echo "cockroachdb-0 not reachable yet"

hr; echo "COCKROACHDB: schema (sail database)"; hr
kubectl exec -it cockroachdb-0 -n default -- \
  ./cockroach sql --insecure --host=cockroachdb-public --database=sail \
  -e "SHOW TABLES;" 2>/dev/null || echo "sail database not seeded yet"

hr; echo "COCKROACHDB: table row counts (sail database)"; hr
kubectl exec -it cockroachdb-0 -n default -- \
  ./cockroach sql --insecure --host=cockroachdb-public --database=sail -e "
    SELECT 'project' AS table, count(*) FROM project
    UNION ALL SELECT 'virtual_machine', count(*) FROM virtual_machine
    UNION ALL SELECT 'policy', count(*) FROM policy
    UNION ALL SELECT '\"user\"', count(*) FROM \"user\"
    UNION ALL SELECT 'firewall_rule', count(*) FROM firewall_rule
    UNION ALL SELECT 'audit_log', count(*) FROM audit_log;
  " 2>/dev/null || echo "sail database not seeded yet"

hr; echo "COCKROACHDB: full column-level schema (sail database)"; hr
kubectl exec -it cockroachdb-0 -n default -- \
  ./cockroach sql --insecure --host=cockroachdb-public --database=sail \
  -e "SELECT table_name, column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public'
      ORDER BY table_name, ordinal_position;" 2>/dev/null || \
  echo "sail database not seeded yet"

hr; echo "VICTORIAMETRICS: health"; hr
VM_SVC="$(kubectl get svc -n default \
  -l "app.kubernetes.io/instance=victoria-metrics,app.kubernetes.io/component=server" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

if [ -n "${VM_SVC}" ]; then
  kubectl run vm-health-check --rm -i --restart=Never --image=curlimages/curl -n default -- \
    curl -s "http://${VM_SVC}.default.svc.cluster.local:8428/health" 2>/dev/null || \
    echo "VictoriaMetrics not reachable yet"
else
  echo "VictoriaMetrics service not found"
fi

hr; echo "VICTORIAMETRICS: series count"; hr
if [ -n "${VM_SVC}" ]; then
  kubectl run vm-series-check --rm -i --restart=Never --image=curlimages/curl -n default -- \
    curl -s "http://${VM_SVC}.default.svc.cluster.local:8428/api/v1/series/count" 2>/dev/null || \
    echo "Could not fetch series count"
fi

hr; echo "Done."; hr