#!/usr/bin/env bash
# user-data.sh — Idempotent bootstrap for Debian 12 K3s node
# Templated by Terraform. Variables: ${github_org}, ${github_repo}, ${project_name}
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

LOG=/var/log/bootstrap.log
exec > >(tee -a "$LOG") 2>&1

echo "=== Bootstrap started at $(date) ==="

# ---------------------------------------------------------------------------
# 1. System packages
# ---------------------------------------------------------------------------
apt-get update -qq
apt-get install -y --no-install-recommends \
  curl \
  git \
  ca-certificates \
  gnupg \
  lsb-release \
  htop \
  jq \
  unzip

# ---------------------------------------------------------------------------
# 2. Swap — 3 GB swapfile as OOM buffer for t3.medium
# ---------------------------------------------------------------------------
if ! swapon --show | grep -q /swapfile; then
  dd if=/dev/zero of=/swapfile bs=1G count=3 status=progress
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
sysctl -w vm.swappiness=30
sysctl -w vm.overcommit_memory=1
echo 'vm.swappiness=30' >> /etc/sysctl.d/99-k3s.conf
echo 'vm.overcommit_memory=1' >> /etc/sysctl.d/99-k3s.conf

# ---------------------------------------------------------------------------
# 3. K3s — disable Traefik + ServiceLB to save ~150 MB RAM
# ---------------------------------------------------------------------------
if ! command -v k3s &>/dev/null; then
  curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server \
      --disable traefik \
      --disable servicelb \
      --write-kubeconfig-mode 644 \
      --kubelet-arg eviction-hard=memory.available<256Mi \
      --kubelet-arg eviction-soft=memory.available<512Mi \
      --kubelet-arg eviction-soft-grace-period=memory.available=2m" \
    sh -
else
  echo "k3s already installed — skipping"
fi

# Wait for node Ready (timeout 3 min)
echo "Waiting for K3s node to be Ready..."
KUBECONFIG=/etc/rancher/k3s/k3s.yaml
timeout 180 bash -c \
  "until kubectl --kubeconfig=$KUBECONFIG get nodes --no-headers 2>/dev/null | grep -q ' Ready'; do sleep 5; done"
echo "K3s node is Ready"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# ---------------------------------------------------------------------------
# 4. Helm
# ---------------------------------------------------------------------------
if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "Helm already installed — skipping"
fi

# ---------------------------------------------------------------------------
# 5. Helm repos
# ---------------------------------------------------------------------------
helm repo add argo    https://argoproj.github.io/argo-helm   2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts   2>/dev/null || true
helm repo update

# ---------------------------------------------------------------------------
# 6. ArgoCD — Helm install with memory-tuned values
# ---------------------------------------------------------------------------
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Write ArgoCD values inline
cat > /tmp/argocd-values.yaml <<'ARGOCD_VALUES'
global:
  nodeSelector: {}

redis:
  resources:
    requests:
      cpu: 50m
      memory: 32Mi
    limits:
      cpu: 200m
      memory: 128Mi

server:
  replicas: 1
  service:
    type: NodePort
    nodePortHttp: 32080
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 250m
      memory: 256Mi
  extraArgs:
    - --insecure   # No TLS for demo; Grafana and ArgoCD on plain HTTP

repoServer:
  replicas: 1
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

applicationSet:
  replicas: 1
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

notifications:
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 128Mi

controller:
  replicas: 1
  args:
    operationProcessors: "2"
    statusProcessors: "5"
    appResyncPeriod: "180"
  resources:
    requests:
      cpu: 100m
      memory: 192Mi
    limits:
      cpu: 500m
      memory: 768Mi

configs:
  params:
    server.insecure: true
ARGOCD_VALUES

helm upgrade --install argocd argo/argo-cd \
  --version 9.4.17 \
  --namespace argocd \
  --values /tmp/argocd-values.yaml \
  --atomic \
  --timeout 10m \
  --wait

echo "ArgoCD deployed"

# ---------------------------------------------------------------------------
# 7. Apply the Root App of Apps
# ---------------------------------------------------------------------------
cat > /tmp/root-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/${github_org}/${github_repo}.git
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

kubectl apply -f /tmp/root-app.yaml

echo "=== Bootstrap complete at $(date) ==="
echo "=== ArgoCD UI: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):32080 ==="
echo "=== Grafana UI: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000  ==="
