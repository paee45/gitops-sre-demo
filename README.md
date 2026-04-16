# 🚀 AI-Powered GitOps SRE Platform

**DevOps + SRE + AI Observability Demo**

End-to-end platform demonstrating modern cloud engineering best practices: GitOps delivery, CI/CD promotion pipelines, API governance with Kong, full LGTM observability stack, and an AI-assisted SRE layer for incident analysis.

> 👉 Everything runs on a **single AWS EC2 t3.medium (~$33/month)** — 
> [Jump to live demo & walkthrough →](#showcase)

---

## ⚡ What This Proves (in 30 seconds)

- ✅ **GitOps deployment** with Argo CD App of Apps — zero manual `kubectl apply`
- ✅ **Full CI quality gate** — lint (`golangci-lint`), unit tests (`go test -race`), coverage upload, then Trivy image scan blocks on CRITICAL/HIGH CVEs before any push
- ✅ **CD promotion pipeline** — GitHub Actions (build + push to GHCR) → Codefresh (dev → staging → production with approval gates)
- ✅ **API control** via Kong — JWT auth, rate limiting (60 req/min), observable 3-phase demo
- ✅ **Full observability** with Grafana LGTM stack (Logs + Metrics + Traces) + correlated drill-down
- ✅ **Incident-ready** system with SLO dashboards, self-healing ArgoCD, and Prometheus alerting
- ✅ **AI SRE foundation** — RAG vector store (ChromaDB) deployed; LLM incident analysis wired in design
- ✅ **Secure by design** — OIDC (no static keys), IAM permission boundaries, Trivy SARIF → GitHub Security tab, least-privilege RBAC

---

## 🧠 Architecture Overview

```
Developer → PR / push to main (src/** changed)
          ↓
┌─────────────────────────────────────────────────────────────┐
│  ci.yml  — CI gate (blocks everything below if it fails)    │
│  ① golangci-lint  ② go test -race  ③ Trivy image scan       │
│     (exit-code:1 on CRITICAL/HIGH CVEs → SARIF to GitHub)   │
└─────────────────────────────────────────────────────────────┘
          ↓  (only if ci.yml succeeded on main)
┌─────────────────────────────────────────────────────────────┐
│  build-images.yml  — triggered by workflow_run              │
│  ① docker buildx → push ghcr.io/paee45/{service}:{sha}      │
│  ② post-push Trivy warn scan                                │
│  ③ POST Codefresh API  (IMAGE_TAG = short SHA)              │
└─────────────────────────────────────────────────────────────┘
          ↓
┌─────────────────────────────────────────────────────────────┐
│  codefresh.yml  — CD promotion pipeline                     │
│  dev      → auto-promote (commits k8s/envs/dev.env)         │
│  staging  → pending-approval (48h timeout) → commit         │
│  prod     → pending-approval (72h timeout) → patch          │
│             k8s/apps/*/deployment.yaml + signed git tag      │
└─────────────────────────────────────────────────────────────┘
          ↓  (ArgoCD polls git every ~3 min, selfHeal=true)
┌─────────────────────────────────────────────────────────────┐
│  ArgoCD App-of-Apps  — auto-sync on k3d / EC2               │
│  Kong (JWT auth + rate limiting)                            │
│  service-a / service-b / service-dashboard                  │
│  Grafana Alloy → Mimir · Loki · Tempo  (LGTM stack)         │
└─────────────────────────────────────────────────────────────┘
          ↓
Prometheus alerts → ChromaDB RAG → LLM Incident Summary (in design)
```

---

## 🎯 Key Demo Scenarios

### 🔥 1. Safe GitOps Deployment
Push a commit → GitHub Actions builds the image → Codefresh promotes it through environments (with approval gates) → ArgoCD syncs Kubernetes → **Deployment Health dashboard** validates error rate, P95 latency, and pod stability in real time. A deploy isn't "done" until the SLO gauges stay green.

### 🚨 2. API Attack & Recovery (Kong 3-Phase Demo)
- **Phase 1** — hit service-a directly with 500 concurrent requests → error rate spikes (no protection)
- **Phase 2** — same flood through Kong without a JWT → 100% `401`, service-a receives zero requests
- **Phase 3** — burst with valid JWT → first 60 req/min pass (`200`), remainder return `429`; service-a P95 latency stays flat

Observable in real time on the **Kong — Traffic & Protection** Grafana dashboard.

### 🤖 3. AI SRE Assistant (RAG Layer)
ChromaDB vector store is running in the `aiops` namespace, indexed nightly from README, Kubernetes manifests, alert rules, and Grafana dashboard definitions. Designed to augment LLM prompts with project-specific context for zero-hallucination incident summaries:
- *"What does `KongHighRateLimitHit` mean and what is the runbook?"*
- *"Which service is failing and what changed before the incident?"*
- *"Is this an SLO violation? What is the remediation step?"*

---

## 🧩 Tech Stack

| Area | Tools |
|---|---|
| **CI** | GitHub Actions — lint (`golangci-lint`), test (`go test -race` + coverage), Trivy scan (blocks on CRITICAL/HIGH), build + push to GHCR |
| **CD / Promotion** | Codefresh (dev → staging → production, approval gates) |
| **GitOps** | Argo CD (App of Apps, self-managed) |
| **Infrastructure** | Terraform (S3+DynamoDB backend, OIDC provider, permission boundaries) |
| **Cloud** | AWS EC2 t3.medium — Debian 12, K3s |
| **API Gateway** | Kong (DB-less KIC — JWT auth, rate limiting, Prometheus metrics) |
| **Metrics** | Grafana Mimir (remote-write target, 7-day retention) |
| **Logs** | Grafana Loki (structured LogQL, 7-day retention) |
| **Traces** | Grafana Tempo (OTLP, trace↔log↔metric correlation) |
| **Collector** | Grafana Alloy (DaemonSet, River config, pod annotation scraping) |
| **Dashboards** | Grafana 12 — 10 dashboards (7 community + 3 custom GitOps ConfigMaps) |
| **Alerting** | Prometheus + Alertmanager (4 Kong/SLO alert rules + recording rules for forecast) |
| **AI Layer** | ChromaDB (RAG vector store) + sentence-transformers (local embeddings) |
| **Security** | IAM OIDC (no static credentials), permission boundaries, Trivy image scanning |
| **Services** | Go (service-a HTTP API + service-b worker), React + Node.js dashboard |

---

## 📊 Observability (LGTM)

- **Metrics** — Prometheus + Mimir: latency P95, error rate, SLO gauges, ArgoCD sync frequency
- **Logs** — Loki: structured JSON via `slog`, LogQL queries, `traceID` correlation field
- **Traces** — Tempo: OTLP from Go services, span metrics → Mimir, service topology map
- **Dashboards** — Grafana: Deployment Health · Kong Traffic · Tempo Distributed Traces · cluster/node/container resources
- **Correlation** — click a trace span → jump to the exact Loki log line; click a log `traceID` → full flame graph in Tempo

---

## 🤖 AI SRE Assistant

The AIOps strategy is structured in 8 layers. Deployed today:

| Layer | Status | What it does |
|---|---|---|
| Metrics + Dashboards | ✅ Active | Kong + deployment SLO dashboards with PromQL |
| Prometheus Alerting | ✅ Active | 4 alert rules (429 rate, 401 rate, 5xx SLO, P95 latency) |
| Log Anomaly Ratio | 🔲 Planned | Loki ratio: current vs 1-hour baseline — fires at 3×, pages at 10× |
| IsolationForest | 🔲 Planned | Multi-dimensional pattern detection on Loki log vectors |
| Metric Forecasting | 🔲 Planned | Prophet model on Mimir 7-day history — alert *before* rate limit ceiling hit |
| LLM Incident Response | 🔲 Planned | Flask endpoint in Service Dashboard: one-click incident summary |
| **RAG Foundation** | ✅ **Deployed** | ChromaDB in `aiops` ns + nightly indexer: runbooks / incidents / dashboards |
| Synthetic Load AI | 🔲 Planned | AI-generated realistic traffic patterns for stress testing |

---

## 🔐 DevSecOps

- **No static AWS credentials** — GitHub Actions uses OIDC JWT tokens (15-min TTL STS credentials)
- **Trivy image scanning** — runs at build time (`ci.yml`) before push; `exit-code: 1` blocks CI on CRITICAL/HIGH CVEs; SARIF results uploaded to GitHub Security tab automatically
- **IAM permission boundaries** — hard-cap on all roles; privilege escalation via Terraform is structurally blocked
- **Least-privilege RBAC** — two-role CI/CD pattern: `plan` role (read-only, any branch) + `apply` role (write, `main` + approval gate only)
- **SSH key management** — generated by Terraform, stored in AWS Secrets Manager, never on disk or in git

---

## 🛠️ Quick Start

```bash
# 1. Provision AWS infrastructure (optional — skip for local k3d demo)
cd terraform && terraform apply

# 2. Edit a service and push — this triggers the full pipeline
git push origin main
# ↳ ci.yml runs: lint → test → Trivy scan
# ↳ if CI passes: build-images.yml builds & pushes to GHCR
# ↳ Codefresh is triggered: auto-promotes to dev, waits for approval before staging/prod

# 3. Monitor GitOps sync
KUBECONFIG=~/.kube/ai-sandbox/config kubectl get applications -n argocd

# 4. Open dashboards
# Grafana:           http://localhost:3000  (or <public-ip>:3000 on EC2)
# ArgoCD:            http://localhost:32080
# Kong proxy:        http://localhost:8000
# Service Dashboard: http://localhost:8090
```

> Full local k3d setup and AWS bootstrap guide below.

---

## 📌 Why This Matters

This project demonstrates how to:
- Build **production-ready delivery pipelines** — promotable, approval-gated, audit-trailed
- Operate systems with **SRE best practices** — SLO-validated deploys, self-healing GitOps, alert rules
- Implement **observability-driven debugging** — correlated logs, metrics, and traces in one click
- Apply **AI to real operational problems** — RAG-grounded incident analysis, metric forecasting design

---

## 👤 Author

**Rattanakorn Rerkdee**  
SRE / Platform Engineer — GitOps · Observability · AI

> Not just deployment — this is a complete platform for **building, operating, and debugging** modern cloud systems.

---

---

## 🛠️ Local Demo Setup (k3d)

The entire platform runs locally on **k3d** — no AWS account required for running the demo.

### Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Docker Desktop | ≥ 24 | k3d node runtime |
| k3d | ≥ 5.6 | local Kubernetes |
| kubectl | ≥ 1.29 | cluster interaction |
| ArgoCD CLI | ≥ 2.10 | optional — UI login helper |
| Go | ≥ 1.21 | local build / test |

### 1 — Create the cluster

```bash
k3d cluster create gitops-sre-demo \
  --servers 1 --agents 2 \
  -p "8000:8000@loadbalancer" \
  -p "8090:8090@loadbalancer" \
  -p "3000:3000@loadbalancer" \
  -p "32080:32080@loadbalancer" \
  --wait

# Export the kubeconfig (all kubectl commands use this)
export KUBECONFIG=~/.kube/ai-sandbox/config
```

### 2 — Bootstrap ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available deploy/argocd-server -n argocd --timeout=120s

# Install the root App-of-Apps
kubectl apply -f argocd/root-app.yaml
```

ArgoCD will recursively discover every `k8s/**/app.yaml` and sync all stacks in the correct wave order.

### 3 — Access the platform

| Service | URL | Default credentials |
|---|---|---|
| ArgoCD | http://localhost:32080 | `admin` / `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |
| Grafana | http://localhost:3000 | `admin` / `admin` |
| Kong proxy | http://localhost:8000 | — |
| Service Dashboard | http://localhost:8090 | — |

### 4 — Run the demo scenarios

**Safe deployment** — edit any `src/` file, push; GitHub Actions builds the image → Codefresh promotes → ArgoCD syncs → Deployment Health dashboard stays green.

**API attack simulation (load generator):**

```bash
# Phase 1 — direct attack (no gateway)
kubectl apply -f demo/load-generator/phase1-direct-attack.yaml

# Phase 2 — through Kong, no JWT (all 401)
kubectl apply -f demo/load-generator/phase2-kong-unauth.yaml

# Phase 3 — valid JWT, rate limited (429 after 60 req/min)
kubectl apply -f demo/load-generator/phase3-kong-ratelimited.yaml
```

Watch the **Kong — Traffic & Protection** dashboard in real time.

---

## 🔐 AWS / Terraform Setup (optional)

The Terraform config provisions an EC2 instance to run the same k3d cluster in the cloud. It uses OIDC — no static AWS credentials anywhere.

### OIDC credential flow

```
GitHub Actions runner
    │  requests OIDC JWT (audience: sts.amazonaws.com)
    ▼
GitHub OIDC provider (token.actions.githubusercontent.com)
    │  issues signed JWT (sub: repo:paee45/gitops-sre-demo:ref:refs/heads/main)
    ▼
AWS STS AssumeRoleWithWebIdentity → Temporary credentials (15-min TTL)
```

### Two-role CI/CD pattern

| Role | Scope | Permissions |
|---|---|---|
| `gitops-sre-demo-github-plan` | Any branch / PR | EC2 describe, S3 state read, DynamoDB read |
| `gitops-sre-demo-github-actions` | `main` only + production approval | EC2 full, S3 state write, Secrets Manager |

### Permission boundary

Every role created by Terraform has a `permissions_boundary` hard-capping it to EC2 + this project's S3/DynamoDB/Secrets Manager resources. Privilege escalation via over-scoped Terraform is structurally blocked.

### Required GitHub Secrets / Variables

| Secret / Var | Where | Value |
|---|---|---|
| `AWS_PLAN_ROLE_ARN` | Secret | ARN of the plan role (from `terraform output`) |
| `AWS_APPLY_ROLE_ARN` | Secret | ARN of the apply role (from `terraform output`) |
| `AWS_ACCOUNT_ID` | Secret | Your personal AWS account ID |
| `CODEFRESH_API_TOKEN` | Secret | Codefresh → User Settings → API Keys |
| `AWS_REGION` | Variable | e.g. `ap-southeast-1` |
| `TF_STATE_BUCKET` | Variable | S3 bucket name from bootstrap |
| `TF_STATE_DYNAMODB_TABLE` | Variable | DynamoDB table name from bootstrap |

### Bootstrap (first time only)

```bash
# Option A — CloudFormation (no local Terraform needed)
# GitHub → Actions → "Bootstrap Terraform Backend" → Run workflow

# Option B — local Terraform
cd terraform/bootstrap
terraform init
terraform apply     # creates S3 bucket + DynamoDB table
```

After bootstrap:

```bash
cd terraform
terraform init
# Push to main or open a PR — GitHub Actions runs plan automatically
```

SSH key is generated by Terraform and stored in AWS Secrets Manager — never on disk:

```bash
terraform -chdir=terraform output -raw ssh_command | bash
```

---

## 📁 Repository Structure

```
.github/
  workflows/
    ci.yml              ← lint + unit test + Trivy scan (CI gate)
    build-images.yml    ← docker build + push to GHCR + post-push Trivy
    pipeline.yml        ← Terraform plan (PR) + apply (main, approval gate)
    bootstrap.yml       ← one-time S3 + DynamoDB bootstrap via CloudFormation
argocd/
  root-app.yaml         ← App-of-Apps entry point (apply this once)
codefresh.yml           ← CD promotion: dev → staging → production
demo/
  load-generator/       ← k8s Jobs for the 3-phase Kong attack demo
k8s/
  aiops/                ← ChromaDB vector store + RAG indexer
  apps/                 ← service-a, service-b, service-dashboard ArgoCD apps
  argocd/               ← ArgoCD self-management (values + app)
  envs/                 ← dev.env / staging.env / production.env (image tags)
  kong/                 ← Kong gateway (DB-less KIC, JWT, rate limiting)
  kong-config/          ← KongConsumer + KongPlugin CRs
  kong-crds/            ← Kong CRD install (sync-wave 0)
  observability/
    alloy/              ← DaemonSet collector (pod metrics, node, cAdvisor, logs, traces)
    grafana/            ← dashboards + values
    loki/               ← log storage (SingleBinary)
    mimir/              ← metrics storage (monolithic)
    prometheus/         ← standalone scrape + Alertmanager + alert/recording rules
    tempo/              ← trace storage (OTLP)
src/
  service-a/            ← Go HTTP API (orders endpoint, Prometheus + OTLP)
  service-b/            ← Go background worker (jobs, Prometheus + OTLP)
  service-dashboard/    ← React + Node.js dashboard (load-test UI, JWT helper)
terraform/
  bootstrap/            ← S3 + DynamoDB backend provisioning
  *.tf                  ← EC2, OIDC provider, IAM roles + permission boundaries
```

---

## 👤 Author

**Rattanakorn Rerkdee** — SRE / Platform Engineer  
GitOps · Observability · AI · Cloud Security

> Not just deployment — a complete platform for **building, operating, and debugging** production cloud systems.
