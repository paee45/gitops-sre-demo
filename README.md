# �️ gitops-sre-demo

> **Work in progress.** This is a personal weekend / after-hours project where I get to wire up all the tools I find interesting and see how far I can push a single-node cluster. Pull up a chair — it's a fun one.

---

## 🤔 Why Does This Exist?

I got tired of working on systems where observability was bolted on as an afterthought. I wanted a playground where I could:

- **See every signal at once** — traces, logs, and metrics all correlated, not siloed in three different dashboards
- **Understand what "safe deployment" actually means** — not just "it deployed", but SLO gauges staying green *after* the rollout
- **Break things on purpose** — flood an API with requests, watch it fail, put a Kong gateway in front, and watch it hold
- **Play with AI in a real operational context** — not chatbot demos, but plugging an LLM into actual alert/runbook/incident data and seeing if it's useful

Everything runs on a **single k3d cluster** (or an EC2 t3.medium if you want it in the cloud). No giant infra bill, no team required.

---

## ✨ What Makes This Interesting

### 🤖 The AI SRE Layer (the whole point)
- **RAG-grounded incident analysis** — ChromaDB vector store in the cluster, indexed nightly from runbooks, manifests, alert rules, and Grafana dashboard definitions
- **No hallucination by design** — the LLM gets retrieved context chunks alongside the alert; it can't make up facts about *your* system
- **Local-first** — `sentence-transformers/all-MiniLM-L6-v2` does embeddings in-cluster, no external API key needed for the foundation layer
- **Alertmanager → LLM webhook** *(planned)* — when an alert fires, it automatically queries ChromaDB and calls the LLM for a structured incident report
- **Ollama integration** *(planned)* — local `llama3.2:3b` in the cluster so the full AI loop works with zero external dependencies

### 📊 Observability Foundation (what the AI reads from)
- **LGTM stack** — Mimir (metrics) + Loki (logs) + Tempo (traces) + Grafana; full correlation: click a trace → jump to the exact log line
- **Structured signals** — services emit JSON logs with `traceID` field, OTLP spans, and labelled Prometheus metrics; everything is queryable
- **4 alert rules** — `KongHighRateLimitHit`, `KongHighUnauthorizedRate`, `ServiceHighErrorRate`, `ServiceHighLatencyP95` — each maps to a runbook chunk in ChromaDB

### 🔁 GitOps + CI/CD (the delivery backbone)
- **CI gate** — `golangci-lint` + `go test -race` + Trivy scan; image push gated on CI success via `workflow_run`
- **Multi-stage CD** — GitHub Actions → Codefresh (auto-promote to dev, human approval for staging & prod)
- **ArgoCD App-of-Apps** — zero manual `kubectl apply` after initial bootstrap; `selfHeal: true`

### 🛡️ API Protection Demo (the fun bit)
- **Kong 3-phase attack** — direct flood (chaos) → Kong without JWT (all 401s) → valid JWT rate limited (429 after 60 req/min). Watch all three live in Grafana.

---

## 🗺️ How It All Fits Together

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

## � Try These Demo Scenarios

### 🔥 1. Watch a Safe Deployment Happen

Push any change to `src/` and watch the whole chain activate: GitHub Actions lints + tests + scans, the image lands on GHCR, Codefresh promotes it to dev automatically, then waits for your approval before touching staging or prod. All the while the **Deployment Health** dashboard shows error rate and P95 latency in real time. When the gauges stay green — it's done.

### 💥 2. The Kong Attack Demo (my favourite)

This is the most fun bit. There are three prebuilt load generators:

- **Phase 1** — blast `service-a` directly with 500 concurrent requests. Error rate explodes. No protection.
- **Phase 2** — same flood, but routed through Kong without a JWT. Service-a gets exactly zero requests. All `401`.
- **Phase 3** — flood with a valid JWT. First 60 req/min get `200`. Everything else gets `429`. Service-a P95 latency barely moves.

Watch all three phases live on the **Kong — Traffic & Protection** Grafana dashboard. It's very satisfying.

### 🤖 3. The AI SRE Bit (early, but working)

ChromaDB is running in the `aiops` namespace, indexed from the project's runbooks, manifests, alert rules, and dashboard definitions. The design: when an alert fires, an LLM gets the alert *plus* the relevant context chunks retrieved from ChromaDB — so instead of a generic "high error rate" message, it can say *"the `KongHighRateLimitHit` rule fired; the runbook says check consumer quotas first; the last similar incident was resolved by..."*

Still early stage, but the RAG foundation is live and queryable.

---

## 🧩 What's Under the Hood

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

## 🤖 AI SRE Layer — Work in Progress

The AIOps stack is being built in layers. Here's where things stand:

| Layer | Status | What it does |
|---|---|---|
| Metrics + Dashboards | ✅ Running | Kong + deployment SLO dashboards, all wired up |
| Prometheus Alerting | ✅ Running | 4 alert rules: 429 rate, 401 rate, 5xx SLO, P95 latency |
| **RAG Foundation** | ✅ **Running** | ChromaDB in `aiops` ns, nightly indexer, runbooks/manifests/alerts queryable |
| Log Anomaly Ratio | 🚧 Next | Loki ratio: current vs 1h baseline — fires at 3×, pages at 10× |
| Metric Forecasting | 🚧 Planned | Prophet on 7-day Mimir history — alert *before* you hit the ceiling |
| LLM Incident Response | 🚧 Planned | One-click incident summary from the service dashboard |
| IsolationForest | 🚧 Planned | Multi-dimensional pattern detection on log vectors |
| Synthetic Load AI | 🚧 Idea | AI-generated realistic traffic patterns for chaos testing |

---

## 🔐 Security Stuff I Care About

- **No static AWS credentials** — GitHub Actions uses OIDC JWT tokens (15-min TTL STS creds, rotated automatically)
- **Trivy image scanning** — runs in CI before any push, blocks on CRITICAL/HIGH CVEs, results go to the GitHub Security tab
- **IAM permission boundaries** — every role is hard-capped; even if Terraform tried to escalate privileges, it structurally can't
- **Least-privilege RBAC** — two-role CI/CD split: read-only for any branch, write only on `main` + approval
- **SSH keys via Secrets Manager** — Terraform generates the key, stores it in AWS Secrets Manager, never touches disk or git

---

## � Getting Started (local, no AWS needed)

The whole thing runs on k3d. You don't need an AWS account to try it.

### What you need

| Tool | Version | Install |
|---|---|---|
| Docker Desktop | ≥ 24 | [docker.com](https://docs.docker.com/get-docker/) |
| k3d | ≥ 5.6 | `brew install k3d` |
| kubectl | ≥ 1.29 | `brew install kubectl` |

### Spin it up

```bash
# 1. Create the cluster with the right port mappings
k3d cluster create gitops-sre-demo \
  --servers 1 --agents 2 \
  -p "8000:8000@loadbalancer" \
  -p "8090:8090@loadbalancer" \
  -p "3000:3000@loadbalancer" \
  -p "32080:32080@loadbalancer" \
  --wait

export KUBECONFIG=~/.kube/ai-sandbox/config

# 2. Bootstrap ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available deploy/argocd-server -n argocd --timeout=120s

# 3. Install the App-of-Apps — ArgoCD handles everything else from here
kubectl apply -f argocd/root-app.yaml
```

Grab a coffee. ArgoCD will discover and sync all the stacks in sync-wave order. ~5 minutes.

### Where things are

| Service | URL | Login |
|---|---|---|
| **Grafana** | http://localhost:3000 | `admin` / `admin` |
| **ArgoCD** | http://localhost:32080 | `admin` / *(see below)* |
| **Service Dashboard** | http://localhost:8090 | — |
| **Kong proxy** | http://localhost:8000 | — |

```bash
# ArgoCD initial password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

### Run the demo scenarios

```bash
# Phase 1 — direct attack (no gateway)
kubectl apply -f demo/load-generator/phase1-direct-attack.yaml

# Phase 2 — through Kong, no JWT (watch the 401s pile up)
kubectl apply -f demo/load-generator/phase2-kong-unauth.yaml

# Phase 3 — valid JWT, rate limited (first 60/min pass, rest get 429)
kubectl apply -f demo/load-generator/phase3-kong-ratelimited.yaml
```

Open the **Kong — Traffic & Protection** dashboard in Grafana and watch it happen in real time.

---

## ☁️ Running on EC2 (optional)

If you want it in the cloud instead, the Terraform config provisions a t3.medium with k3d pre-installed. It uses OIDC — no static credentials anywhere.

```bash
cd terraform
terraform init
terraform plan   # check what it'll do
# (then apply via GitHub Actions on merge to main)
```

See the repo structure section for what's where.

---

## 📁 Repo Layout

```
.github/
  workflows/
    ci.yml              ← lint + test + Trivy (blocks image push on failure)
    build-images.yml    ← docker build → GHCR push (only runs if CI passes)
    pipeline.yml        ← Terraform plan on PR, apply on main
    bootstrap.yml       ← one-time S3 + DynamoDB setup
argocd/
  root-app.yaml         ← the single file you apply to bootstrap everything
codefresh.yml           ← dev auto-promote → staging approval → prod approval
demo/
  load-generator/       ← the three Kong attack phases as k8s Jobs
k8s/
  aiops/                ← ChromaDB vector store + nightly RAG indexer
  apps/                 ← service-a, service-b, service-dashboard
  argocd/               ← ArgoCD manages itself (meta)
  envs/                 ← dev.env / staging.env / production.env (image tags)
  kong/                 ← DB-less Kong (JWT auth + rate limiting)
  observability/
    alloy/              ← Grafana Alloy DaemonSet (metrics + logs + traces collector)
    grafana/            ← dashboards as ConfigMaps + values
    loki/               ← log storage
    mimir/              ← metrics storage
    prometheus/         ← scraping + alerting rules
    tempo/              ← trace storage (OTLP)
src/
  service-a/            ← Go HTTP API (orders, Prometheus + OTLP instrumented)
  service-b/            ← Go background worker (jobs, Prometheus + OTLP)
  service-dashboard/    ← React + Node.js UI (load test runner, JWT helper)
terraform/
  bootstrap/            ← S3 + DynamoDB for Terraform state
  *.tf                  ← EC2, OIDC, IAM roles + permission boundaries
```

---

## 🤝 Contributing / Questions

This is a personal project but I'm happy to chat about any of it. Open an issue, start a discussion, or just fork it and break things — that's the point.

---

*Built by [Rattanakorn Rerkdee](https://github.com/paee45) — always a work in progress.*


BACKLOG.md as a reference doc — check things off as they land. Add notes inline.