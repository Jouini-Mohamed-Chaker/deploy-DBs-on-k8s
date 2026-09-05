# K3s + CockroachDB + VictoriaMetrics + MetalLB — Lab Setup Guide

Scope agreed: k3s (not full kubeadm), single-node VictoriaMetrics, no Istio,
Helm charts wherever possible, one control node + 3 worker VMs.

---

## 1. VM specs — 2-node topology (1 control + 1 worker)

k3s server nodes are schedulable by default (no control-plane taint like
kubeadm), so with only 2 machines both of them run workloads. That means
each node needs more headroom than in the 4-node layout, because you're
packing the same 3 CockroachDB pods + VictoriaMetrics + MetalLB onto 2
nodes instead of 4.

| Role                    | vCPU | RAM  | Disk  | Count |
|-------------------------|------|------|-------|-------|
| Control node (schedulable) | 4 | 8 GB | 30 GB | 1     |
| Worker node                | 4 | 8 GB | 40 GB | 1     |

Notes:
- **Trade-off of going this small:** CockroachDB will still run as a
  3-pod cluster, but with only 2 physical nodes, at least two of the
  three pods will always share a node. You get a working distributed SQL
  cluster and can test the mechanics, but not real machine-level fault
  tolerance. If you later add a 3rd node, nothing changes config-wise —
  the scheduler will just spread the pods better automatically.
- 8GB RAM per node is the realistic floor once a node is running both
  control-plane components *and* a CockroachDB pod. Going below this
  risks OOM kills under any real load.
- 40GB disk on the worker (30GB on control) because pods will be
  distributed across both, each potentially holding a 10GB CockroachDB
  PVC.
- OS: any recent Ubuntu Server LTS (22.04/24.04).
- Both VMs need to reach each other over the network, and you need a
  small free block of unused IPs on that same subnet for MetalLB.

**Want it even smaller?** You can go to a single VM (k3s in single-node
mode, no separate worker at all) — same charts, same values files, just
skip step 4 (no agent to join). CockroachDB's 3 pods would all share
one machine, so bump that one VM to ~6 vCPU / 12GB+ if you go this route.
Say the word and I'll adjust the guide for that instead.

---

## 2. Order of operations

1. Provision the 2 VMs, note their IPs.
2. Run `01-prep-node.sh` on **both** VMs.
3. Run `02-install-k3s-server.sh` on the **control node**. Save the printed
   token and IP.
4. Run `03-install-k3s-agent.sh <control-ip> <token>` on the **1 worker**.
5. From the control node, confirm: `kubectl get nodes` → 2 nodes, both `Ready`.
6. Run `04-setup-helm-repos.sh` on the control node.
7. Edit `manifests/metallb-config.yaml` with a real IP range for your network.
8. Install MetalLB, apply the IP pool config.
9. Install CockroachDB via Helm with the provided values.
10. Install VictoriaMetrics via Helm with the provided values.
11. Seed CockroachDB with your schema/data via the seed Job.
12. Seed VictoriaMetrics with your metrics file via the seed script.

---

## 3. Detailed commands

### Step 2-5: bootstrap the cluster
```bash
# on all 4 VMs
./scripts/01-prep-node.sh

# on control node only
./scripts/02-install-k3s-server.sh
# note the token + IP it prints

# on each worker
./scripts/03-install-k3s-agent.sh <CONTROL_NODE_IP> <TOKEN>

# back on control node
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

### Step 6: Helm repos
```bash
./scripts/04-setup-helm-repos.sh
```

### Step 7-8: MetalLB
```bash
helm install metallb metallb/metallb -n metallb-system --create-namespace

# wait for metallb pods to be Running
kubectl get pods -n metallb-system

# edit manifests/metallb-config.yaml first, then:
kubectl apply -f manifests/metallb-config.yaml
```

### Step 9: CockroachDB
```bash
helm install cockroachdb cockroachdb/cockroachdb \
  -f manifests/cockroachdb-values.yaml \
  -n default

# watch until all 3 pods are Running/Ready (can take a couple minutes)
kubectl get pods -l app.kubernetes.io/name=cockroachdb -w
```

### Step 10: VictoriaMetrics
```bash
helm install victoria-metrics vm/victoria-metrics-single \
  -f manifests/victoria-metrics-values.yaml \
  -n default

kubectl get pods -l app.kubernetes.io/name=victoria-metrics-single
```

### Step 11: Seed CockroachDB
```bash
# put your real schema + data into manifests/schema-and-seed.sql first
kubectl create configmap cockroachdb-seed \
  --from-file=seed.sql=manifests/schema-and-seed.sql -n default

kubectl apply -f manifests/cockroachdb-seed-job.yaml

# check it succeeded
kubectl logs job/cockroachdb-seed
```

### Step 12: Seed VictoriaMetrics
```bash
./scripts/05-seed-victoriametrics.sh /path/to/your/metrics-file.txt
```

---

## 4. Exposing things externally (optional)

Since Istio and Traefik are both out of scope, if you want to reach
CockroachDB's SQL/UI port or VictoriaMetrics' HTTP API from outside the
cluster, the simplest route is a plain `LoadBalancer` Service, which
MetalLB will hand a real IP from your pool:

```bash
kubectl expose deployment victoria-metrics-single-server \
  --type=LoadBalancer --port=8428 --name=vm-external -n default
```

(CockroachDB's chart already creates a `cockroachdb-public` Service —
just patch its `type` to `LoadBalancer` if you want external DB access,
or leave it ClusterIP and only reach it from inside the cluster.)

---

## 5. What was cut to keep this simple, and why

- **kubeadm → k3s**: removes manual CNI install, container runtime
  wrangling, and cert bootstrap steps. k3s ships all of that pre-wired.
- **Istio: removed entirely.** It was the single biggest source of
  complexity relative to value for this setup (sidecar injection,
  mTLS quirks with StatefulSets, another CRD set, another control plane
  component). Nothing above needs it — MetalLB + plain Services is enough
  to expose things.
- **VictoriaMetrics cluster mode → single-node**: the clustered variant
  (vminsert/vmselect/vmstorage) triples the moving parts for scale you
  don't need at this size.
- **k3s Traefik + ServiceLB disabled**: you're using MetalLB instead, so
  the built-in load balancer/ingress would just be dead weight and a
  possible port conflict.
- **CockroachDB TLS disabled (insecure mode)**: cert generation/rotation
  is real operational overhead; fine for a lab, not for anything
  reachable from the internet.

If down the line you want to re-add Istio, add it in the same way you'd
add it to any cluster — install via Helm, but explicitly skip sidecar
injection on the CockroachDB and VictoriaMetrics namespaces so the mesh
doesn't sit in front of your database traffic.