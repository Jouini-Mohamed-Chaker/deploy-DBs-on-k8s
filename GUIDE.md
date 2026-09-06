# K3s + CockroachDB + VictoriaMetrics — Lab Setup Guide

Scope: k3s (not full kubeadm), 1 control node + 1 worker node,
single-node VictoriaMetrics, no Istio, no MetalLB, Helm charts wherever
possible. Every step below is a script — nothing to hand-type or
copy-paste into a terminal beyond running the script itself.

---

## 1. VM specs — 2-node topology (1 control + 1 worker)

k3s server nodes are schedulable by default (no control-plane taint like
kubeadm), so with only 2 machines both of them run workloads.

| Role                        | vCPU | RAM  | Disk  | Count |
|------------------------------|------|------|-------|-------|
| Control node (schedulable)  | 4    | 8 GB | 30 GB | 1     |
| Worker node                  | 4    | 8 GB | 40 GB | 1     |

Notes:
- **Trade-off of going this small:** CockroachDB still runs as a 3-pod
  cluster, but with only 2 physical nodes, at least two of the three pods
  will always share a node. You get a working distributed SQL cluster,
  not real machine-level fault tolerance. Adding a 3rd node later needs
  no config changes — the scheduler just spreads pods better.
- 8GB RAM per node is the realistic floor once a node runs both
  control-plane components *and* a CockroachDB pod.
- OS: any recent Ubuntu Server LTS (22.04/24.04).
- Both VMs need to reach each other over the network. No IP pool needed
  since MetalLB isn't used — see section 4 for external access.

---

## 2. Script order

Run these in order. Each one prints what it did and any values you need
for the next step (token, IP, pod status, etc).

| # | Script                              | Run on         |
|---|--------------------------------------|----------------|
| 1 | `01-prep-node.sh`                    | control + worker (both) |
| 2 | `02-install-k3s-server.sh`           | control only   |
| 3 | `03-install-k3s-agent.sh <ip> <token>` | worker only  |
| 4 | `04-setup-helm-repos.sh`             | control only   |
| 5 | `05-install-cockroachdb.sh`          | control only   |
| 6 | `06-install-victoriametrics.sh`      | control only   |
| 7 | `07-seed-cockroachdb.sh`             | control only   |
| 8 | `08-seed-victoriametrics.sh <file>`  | control only   |
| 9 | `09-expose-nodeport.sh` (optional)   | control only   |

**Important — run scripts 4 onward as your normal user, without `sudo`.**
k3s writes its kubeconfig world-readable, so sudo isn't needed for
kubectl/helm — and using sudo on one script but not another puts Helm's
repo config in a different user's home directory each time, which causes
`Error: INSTALLATION FAILED: repo ... not found` even though the repo
was added successfully moments earlier under a different user.

```bash
# 1. on BOTH vms
./scripts/01-prep-node.sh

# 2. on the control node
./scripts/02-install-k3s-server.sh
# copy the printed IP and token for step 3

# 3. on the worker
./scripts/03-install-k3s-agent.sh <CONTROL_NODE_IP> <TOKEN>

# check from the control node before continuing:
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
# expect 2 nodes, both Ready, before moving on

# 4. on the control node, as your normal user (no sudo)
./scripts/04-setup-helm-repos.sh

# 5.
./scripts/05-install-cockroachdb.sh

# 6.
./scripts/06-install-victoriametrics.sh

# 7. (edit manifests/schema-and-seed.sql first if you want different data)
./scripts/07-seed-cockroachdb.sh

# 8.
./scripts/08-seed-victoriametrics.sh /path/to/your/metrics-file.txt

# 9. optional
./scripts/09-expose-nodeport.sh
```

---

## 3. Verifying things worked

```bash
# cluster
kubectl get nodes

# cockroachdb
kubectl get pods -l app.kubernetes.io/name=cockroachdb -n default
kubectl exec -it cockroachdb-0 -- ./cockroach sql --insecure --database=sail \
  -e "SELECT p.name, v.name, v.status FROM virtual_machine v JOIN project p ON v.project_id = p.id;"

# victoriametrics
kubectl get pods -l app.kubernetes.io/name=victoria-metrics-single -n default
kubectl port-forward svc/victoria-metrics-single-server 8428:8428
# then in a browser: http://localhost:8428/vmui
```

---

## 4. Exposing things externally (optional)

MetalLB was dropped — not needed for a lab this size. Two options:

**Option A — NodePort (persistent, reachable at any node's IP):**
```bash
./scripts/09-expose-nodeport.sh
```
Patches `cockroachdb-public` and creates `vm-external`, both as
`NodePort`. Reach them at `http(s)://<any-node-ip>:<port-shown-by-script>`.

**Option B — port-forward (simplest, temporary, no service changes):**
```bash
kubectl port-forward svc/cockroachdb-public 26257:26257
kubectl port-forward svc/victoria-metrics-single-server 8428:8428
```

---

## 5. What was cut to keep this simple, and why

- **kubeadm → k3s**: removes manual CNI install, container runtime
  wrangling, and cert bootstrap steps.
- **Istio: removed entirely.** Biggest complexity-to-value ratio of
  anything considered (sidecar injection, mTLS quirks with StatefulSets,
  another CRD set, another control-plane component). Not needed here.
- **VictoriaMetrics cluster mode → single-node**: the clustered variant
  (vminsert/vmselect/vmstorage) triples the moving parts for scale this
  lab doesn't need.
- **k3s Traefik + ServiceLB disabled, MetalLB dropped entirely**: external
  access goes through plain `NodePort` Services instead — one less
  component, one less thing to misconfigure.
- **CockroachDB TLS disabled (insecure mode)**: cert generation/rotation
  is real operational overhead; fine for a lab, not for anything
  reachable from the internet.

If you later want Istio back: install via Helm, but explicitly skip
sidecar injection on the CockroachDB and VictoriaMetrics namespaces so
the mesh doesn't sit in front of database traffic.