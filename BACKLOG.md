
# 📋 Project Backlog & Roadmap

> Living reference doc — check things off as they land. Add notes inline.  
> Research baseline: modern DevOps/GitOps market standards as of 2025–2026.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Done & shipped |
| 🚧 | In progress / partially done |
| 🔲 | Not started — planned |
| 💡 | Idea / nice-to-have |
| ❌ | Descoped / won't do |

---

## 1. Services & Application Code

### service-a (Go HTTP API)
- ✅ HTTP server with `/orders`, `/healthz`, `/metrics` endpoints
- ✅ Prometheus instrumentation (counter, histogram, gauge)
- ✅ Structured JSON logging with `slog` + `traceID` field
- ✅ OTLP trace exporter (spans to Grafana Alloy → Tempo)
- ✅ Multi-stage Dockerfile: `golang:alpine` → `distroless/static:nonroot`
- ✅ Unit tests: `TestHealthzHandler`, `TestOrdersHandler`, `TestGetEnv`, `TestRandomRegion`
- 🔲 Integration test: hit `/orders` through Kong with valid/invalid JWT, assert 200/401
- 🔲 Benchmark test: `go test -bench` for `/orders` latency baseline

### service-b (Go background worker)
- ✅ Background job loop (synthetic job types, tick-based processing)
- ✅ Prometheus instrumentation
- ✅ Structured JSON logging + OTLP traces
- ✅ Multi-stage Dockerfile: `golang:alpine` → `distroless/static:nonroot`
- ✅ Unit tests: `TestHealthzHandler`, `TestGetEnv`, `TestJobTypes`
- 🔲 Integration test: verify jobs emit expected Prometheus metrics

### service-dashboard (React + Node.js)
- ✅ Load test UI (trigger phase 1/2/3 from browser)
- ✅ JWT generator panel
- ✅ Status panel (service health at a glance)
- ✅ Dockerfile with `USER 1000` + `dumb-init`
- 🔲 Unit tests for Node.js server (no tests exist yet)
- 🔲 E2E test: Playwright or Cypress smoke test hitting the dashboard UI
- 🔲 LLM incident response button — calls AI SRE endpoint, shows summary in UI

---

## 2. CI Pipeline (GitHub Actions)

- ✅ `ci.yml` — lint (`golangci-lint`) + test (`go test -race -count=1`) + coverage upload
- ✅ `ci.yml` — Trivy image scan: `exit-code: 1` on CRITICAL/HIGH CVEs
- ✅ Trivy SARIF → GitHub Security tab (`security-events: write`)
- ✅ `build-images.yml` — gated on `ci.yml` success via `workflow_run` (race condition fixed)
- ✅ `build-images.yml` — docker buildx → push to GHCR `ghcr.io/paee45/{service}:{sha}`
- ✅ `build-images.yml` — post-push Trivy warn scan
- ✅ `pipeline.yml` — Terraform plan on PR, apply on `main` with approval gate
- ✅ `bootstrap.yml` — one-time S3 + DynamoDB backend setup (CloudFormation + Terraform)
- 🔲 `ci.yml` — add `helm lint` + `kubeval` against `k8s/**/*.yaml` manifests
- 🔲 `ci.yml` — add `conftest`/OPA policy check on Kubernetes manifests (no `latest` image tags, resource limits required)
- 🔲 `ci.yml` — codecov or similar for coverage trend tracking over PRs
- 🔲 SBOM generation — add `syft` to generate SBOM artifact, attach to GitHub release
- 🔲 Image signing — `cosign` sign the pushed GHCR image, verify signature in ArgoCD with policy
- 🔲 Reusable workflow — extract lint/test steps into a `.github/workflows/reusable-go-ci.yml` callable from each service
- 🔲 Dependabot / Renovate — automated PRs for Go module bumps, Helm chart version pinning, base image updates
- 🔲 DAST scan — add OWASP ZAP quick scan against service-a after deploy to dev
- 🔲 k6 load test step — run a 30s k6 smoke test in CI against the dev environment after deploy

---

## 3. CD Pipeline (Codefresh)

- ✅ `promote_dev` — auto-promote on new image, commits `k8s/envs/dev.env`
- ✅ `approve_staging` — `pending-approval` step, 48h timeout
- ✅ `promote_staging` — commits `k8s/envs/staging.env` on approval
- ✅ `approve_production` — `pending-approval` step, 72h timeout
- ✅ `promote_production` — patches `k8s/apps/*/deployment.yaml`, commits `k8s/envs/production.env`, creates signed git tag `vYYYYMMDD-<sha>`
- 🔲 Slack/Teams notification step — post to channel on deploy success/failure per environment
- 🔲 DORA metrics tracking — capture `deploy_time`, log lead time in Codefresh step metadata
- 🔲 Smoke test step in Codefresh — run `curl /healthz` after each environment promote, fail pipeline on non-200
- 🔲 Rollback step — if smoke test fails post-promote, re-commit previous image tag automatically
- 🔲 Codefresh pipeline test — unit test the `codefresh.yml` with `cfstep-freestyle` dry-run

---

## 4. GitOps / ArgoCD

- ✅ App-of-Apps pattern — `argocd/root-app.yaml` bootstraps everything
- ✅ `selfHeal: true` + `prune: true` on all apps
- ✅ Sync waves (`argocd.argoproj.io/sync-wave`) for ordered dependency bootstrap
- ✅ ArgoCD manages itself (self-managed via `k8s/argocd/`)
- ✅ `ignoreDifferences` configured for StatefulSet volume claim templates (Mimir fix)
- 🔲 ArgoCD ApplicationSet — replace duplicated `app.yaml` files per service with a generator template (e.g. `git` generator over `k8s/apps/*/`)
- 🔲 ArgoCD Image Updater — polls GHCR, opens PR to update image tag, removes need for Codefresh to commit directly
- 🔲 ArgoCD Notifications — Slack/Teams alerts on sync failure, out-of-sync, or degraded health
- 🔲 ArgoCD Projects — create separate AppProject for `observability`, `apps`, `aiops` with RBAC scoping
- 🔲 Ephemeral PR preview environments — use `vcluster` or namespace isolation + ArgoCD ApplicationSet to spin up per-PR environment
- 🔲 Multi-cluster setup — add a second ArgoCD managed cluster (even if simulated with a second k3d) to demo hub-spoke GitOps
- 🔲 Sync hooks — add `PreSync`/`PostSync` ArgoCD hooks for database migrations or smoke checks

---

## 5. Kong API Gateway

- ✅ DB-less Kong Ingress Controller mode
- ✅ JWT authentication plugin (HS256, validates bearer token)
- ✅ Rate limiting plugin (60 req/min per consumer, local policy, returns 429)
- ✅ Prometheus metrics plugin (global, exposes `/metrics` on port 8100)
- ✅ `KongConsumer` + `KongPlugin` custom resources wired to ingress
- ✅ Demo: 3-phase load generators as Kubernetes Jobs
- 🔲 Kong Canary plugin — split traffic 90/10 between service-a v1 and v2 for canary demo
- 🔲 Request transformer plugin — add correlation ID header injected by Kong to every request
- 🔲 Response transformer plugin — strip sensitive response headers downstream
- 🔲 Kong Developer Portal (Kong Enterprise, or mock with swagger-ui) — expose API docs
- 🔲 Kubernetes Gateway API migration — replace `Ingress` with `HTTPRoute` / `GatewayClass` (Gateway API is the Kubernetes standard post-2024)
- 🔲 mTLS between Kong and upstream services — use cert-manager to issue service certs

---

## 6. Observability — Metrics (Mimir + Prometheus)

- ✅ Prometheus scraping all services (service-a, service-b, Kong, Alloy DaemonSet)
- ✅ Grafana Mimir remote-write (7-day retention, monolithic mode)
- ✅ Recording rules for AIOps metric forecasting pre-aggregation
- ✅ Alert rules: `KongHighRateLimitHit`, `KongHighUnauthorizedRate`, `ServiceHighErrorRate`, `ServiceHighLatencyP95`
- ✅ node-exporter metrics (`node_*`: 257 metrics via Alloy `prometheus.exporter.unix`)
- ✅ cAdvisor / container metrics (`container_*`: 61 metrics via `nodes/proxy` RBAC fix)
- 🔲 Alertmanager routing — configure routes so Kong alerts go to one Slack channel, SLO alerts to another
- 🔲 SLO burn-rate alerts — replace threshold alerts with proper multi-window burn-rate (Sloth or Pyrra can generate these)
- 🔲 PrometheusRule CRD — move alerting rules from Helm values into standalone `PrometheusRule` CRDs for ArgoCD visibility
- 🔲 Exemplars — enable exemplar storage in Prometheus, wire to Tempo trace IDs (already have `traceID` in logs; need exemplar labels on histograms)
- 🔲 `kube-state-metrics` dashboards — already deployed, add dashboard for deployment replicas desired vs available
- 🔲 DORA metrics dashboard — deployment frequency, lead time, change failure rate, MTTR tracked in Grafana

---

## 7. Observability — Logs (Loki)

- ✅ Loki deployed (SingleBinary mode, 7-day retention)
- ✅ Alloy collecting pod logs with structured JSON parsing
- ✅ `traceID` field in service logs → LogQL `| json | traceID="..."` correlation
- 🔲 Log-based alert — `KongHighRateLimitLog`: Loki ruler alerting rule on 429 log entries (parallel to Prometheus alert, but from log side)
- 🔲 Log anomaly ratio rule — Loki `rate()` current window vs 1h rolling baseline; alert at 3× deviation, page at 10×
- 🔲 Loki label cardinality audit — check `label_names` and ensure no high-cardinality dynamic labels (pod names, trace IDs) are used as Loki labels
- 🔲 Structured log fields standardisation — define a `LogSchema` doc (timestamp, level, traceID, spanID, service, msg) and enforce across all services
- 🔲 Log retention policy — configure per-stream retention in Loki (e.g. 30d for production, 7d for dev)

---

## 8. Observability — Traces (Tempo)

- ✅ Tempo deployed (OTLP ingest on port 4318 via Alloy)
- ✅ service-a and service-b emit OTLP spans via `otlptracehttp` exporter
- ✅ Tempo Distributed Traces Grafana dashboard
- ✅ Log → trace correlation via `traceID` field
- 🚧 `OTEL_EXPORTER_OTLP_ENDPOINT` env var set in deployment, but OTEL env not confirmed live in cluster (last exec returned exit 1)
- 🔲 Verify traces flowing: `kubectl exec` into service-a, curl `/orders`, look up trace in Grafana Explore → Tempo
- 🔲 Trace → metric exemplars: emit exemplar on `order_processing_duration_seconds` histogram pointing to trace ID
- 🔲 service-dashboard Node.js OTEL instrumentation — add `@opentelemetry/auto-instrumentations-node` so frontend API calls create traces
- 🔲 Trace sampling policy — configure Alloy tail sampler: 100% for error spans, 10% for success (reduces storage, keeps interesting data)
- 🔲 Service topology map — use Grafana's built-in service graph from Tempo span metrics

---

## 9. Observability — Dashboards (Grafana)

- ✅ Deployment Health dashboard (`deployment-health-configmap.yaml`) — error rate, P95, pod restarts, SLO gauge
- ✅ Kong Traffic & Protection dashboard (`kong-traffic-configmap.yaml`) — 200/401/429 rates, rate-limit hit%, latency breakdown
- ✅ Tempo Distributed Traces dashboard (`tempo-traces-configmap.yaml`) — span explorer, service map
- ✅ Community dashboard: node-exporter-full (ID 1860)
- ✅ Community dashboard: k8s cluster compute resources (ID 15757)
- ✅ Community dashboard: Mimir overview (ID 15736)
- ✅ Community dashboard: Loki operational (ID 13407)
- 🔲 ArgoCD operational dashboard — sync status, app health, rollout history (community ID 14584)
- 🔲 DORA Metrics dashboard — deployment frequency, lead time for changes, MTTR, change failure rate (custom)
- 🔲 AI SRE dashboard — ChromaDB collection sizes, indexer last-run, RAG query latency, LLM response time
- 🔲 SLO summary dashboard — one panel per service with error budget burn rate and remaining budget
- 🔲 Alert overview dashboard — active alerts, alert frequency trend, MTTA (mean-time-to-alert)
- 🔲 Cost visibility dashboard — Kubecost or OpenCost panel showing per-namespace resource cost estimate

---

## 10. AI SRE Layer (AIOps)

- ✅ ChromaDB deployed in `aiops` namespace
- ✅ RAG indexer CronJob (nightly): indexes README, k8s manifests, alert rules, Grafana dashboards into 3 collections (`runbooks`, `incidents`, `dashboards`)
- ✅ Embedding model: `sentence-transformers/all-MiniLM-L6-v2` (local, no API key)
- ✅ Recording rules in Prometheus as foundation for metric forecasting queries
- 🔲 **LLM incident response endpoint** — Flask/FastAPI endpoint in service-dashboard (or standalone pod): on alert webhook, query ChromaDB for context chunks, call LLM (OpenAI/Ollama), return formatted incident summary
- 🔲 **Alertmanager webhook** — configure Alertmanager to POST to LLM endpoint on alert fire; response piped to Slack or stored in Loki as structured log
- 🔲 **Log anomaly detection** — Loki LogQL ratio rule: `rate({level="error"}[5m]) / rate({}[5m])` current vs 1h rolling baseline; fire at 3×
- 🔲 **IsolationForest anomaly detection** — Python job polling Mimir for multi-dimensional metric vectors, sklearn IsolationForest, writes anomaly score back as Prometheus remote-write
- 🔲 **Prophet metric forecasting** — weekly scheduled job: fetch 7-day Mimir history, fit Prophet model, predict next 24h values, alert if forecast exceeds rate-limit threshold before it happens
- 🔲 **Ollama local LLM** — deploy Ollama in the cluster (CPU-only, e.g. `llama3.2:3b`), wire to LLM endpoint — no OpenAI key required for demo
- 🔲 **AI SRE Grafana panel** — custom panel: text input → ChromaDB query → LLM response inline in Grafana
- 🔲 **Runbook auto-generation** — on new alert rule added to `prometheus/values.yaml`, trigger a Job that generates a runbook stub and commits it via GitOps
- 🔲 **Synthetic load AI** — script that varies load pattern (sinusoidal, burst, ramp) to test how well anomaly detection responds to different attack signatures

---

## 11. Security & Policy

- ✅ OIDC credential flow — no static AWS keys, 15-min STS tokens
- ✅ IAM permission boundaries — hard-cap on all roles
- ✅ Two-role CI/CD split: `plan` (read-only, any branch) + `apply` (write, `main` + approval)
- ✅ Trivy image scan in CI (blocks on CRITICAL/HIGH, SARIF to GitHub Security)
- ✅ Distroless / nonroot base images on all Go services
- 🔲 **Kyverno policies** — admission webhooks enforcing: no `latest` tags, resources limits required, no privileged containers, `runAsNonRoot: true`
- 🔲 **Network policies** — add `NetworkPolicy` to each namespace: default-deny-all ingress, explicit allow rules per service
- 🔲 **PodSecurityAdmission** — set namespace labels `pod-security.kubernetes.io/enforce: restricted` on `apps`, `aiops` namespaces
- 🔲 **SBOM + attestation** — `syft` generates SBOM per image, `cosign attest` attaches it, `cosign verify-attestation` in ArgoCD pre-sync hook
- 🔲 **Image signing** — `cosign sign` after GHCR push; `cosign verify` in admission webhook (via Kyverno or Connaisseur)
- 🔲 **Secret scanning** — enable GitHub secret scanning + push protection on the repo
- 🔲 **OpenSSF Scorecard** — target score 7+; run as GitHub Action, badge in README
- 🔲 **Falco runtime security** — DaemonSet watching for suspicious syscalls, write-to-`/etc`, shell spawned in container; output to Loki
- 🔲 **cert-manager** — automate TLS for Kong ingress routes and internal service mesh certs (Let's Encrypt or self-signed CA)

---

## 12. Deployment Patterns & Reliability

- ✅ `livenessProbe` + `readinessProbe` on all services
- ✅ `selfHeal: true` in ArgoCD — cluster drift is corrected automatically
- 🔲 **Argo Rollouts canary** — convert `k8s/apps/service-a/deployment.yaml` to `Rollout` kind, canary steps: 10% → 5m pause → 50% → 5m pause → 100%; AnalysisTemplate checks `orders_total` error rate
- 🔲 **Argo Rollouts blue-green** — service-b blue-green strategy with automatic promotion on green analysis passing
- 🔲 **PodDisruptionBudgets** — add PDB `minAvailable: 1` for service-a and service-b (safety net for node drains)
- 🔲 **HorizontalPodAutoscaler** — HPA for service-a: scale 1→5 on `orders_total` custom metric via Prometheus Adapter
- 🔲 **KEDA** — event-driven autoscaling: scale service-b workers based on number of pending "jobs" in a queue metric
- 🔲 **VPA (Vertical Pod Autoscaler)** — add VPA in `Recommendation` mode for observability pods to right-size CPU/memory requests
- 🔲 **Topology spread constraints** — ensure pods spread across nodes for resilience in multi-node k3d scenarios
- 🔲 **Resource quotas** — set `ResourceQuota` per namespace to cap total CPU/memory consumption

---

## 13. Developer Experience & Tooling

- ✅ `.github/copilot-instructions.md` — AI agent safety rules baked in
- ✅ `scripts/ai-sandbox-setup.sh` — cluster bootstrap helper script
- ✅ `scripts/ai-shell-guard.zsh` — shell guard for accidental context switches
- 🔲 **Devcontainer / codespace** — add `.devcontainer/devcontainer.json` so the project opens ready-to-run in GitHub Codespaces or VS Code Dev Containers (tools: k3d, kubectl, helm, argocd CLI all pre-installed)
- 🔲 **Makefile** — add targets: `make test`, `make lint`, `make build`, `make cluster-up`, `make cluster-down`, `make demo-phase1/2/3`
- 🔲 **Renovate bot** — automated PRs for: Go module updates, Helm chart version bumps, base image digests
- 🔲 **Pre-commit hooks** — add `.pre-commit-config.yaml`: `golangci-lint`, `helm lint`, `kubeval`, `detect-secrets`, `trailing-whitespace`
- 🔲 **Conventional commits + Release Please** — enforce `feat:`, `fix:`, `chore:` commit format; automate changelog and `v*` release tags
- 🔲 **Backstage service catalog** — add `catalog-info.yaml` to each service so they show up in a Backstage developer portal with ownership, docs, runbook links
- 🔲 **OpenFeature / feature flags** — add `flagd` with a `flags.json` ConfigMap; service-a checks a flag before enabling new `/v2/orders` behaviour

---

## 14. Infrastructure (Terraform / AWS)

- ✅ EC2 t3.medium with k3d + K3s
- ✅ OIDC provider for GitHub Actions (no static keys)
- ✅ IAM roles with permission boundaries
- ✅ S3 + DynamoDB Terraform backend (bootstrap)
- ✅ SSH key in AWS Secrets Manager
- 🔲 **Terraform tests** — add `terraform test` (native HCL tests introduced in Terraform 1.6) for the OIDC provider and IAM roles
- 🔲 **tfsec / checkov scan** — add `tfsec` or `checkov` step in `pipeline.yml` to scan Terraform for security misconfigs before plan
- 🔲 **Spot instance option** — add `instance_market_options` for Spot with fallback On-Demand; saves ~70% vs On-Demand on t3.medium
- 🔲 **Auto-shutdown schedule** — Lambda + EventBridge rule to stop EC2 outside working hours (save cost on demo environment)
- 🔲 **Drift detection** — scheduled Terraform plan in GitHub Actions to detect manual AWS console changes (runs on cron, not just push)

---

## 15. Chaos & Testing

- ✅ Phase 1/2/3 load generators (direct attack, JWT missing, rate limited) as k8s Jobs
- 🔲 **Chaos Mesh or Litmus** — add `ChaosExperiment` manifests: pod-kill on service-a, network delay 200ms, CPU stress; observe recovery via Deployment Health dashboard
- 🔲 **k6 load test** — replace `hey`/`wrk`-based load generators with k6 scripts that produce structured output; integrate with Grafana k6 dashboard (community ID 18030)
- 🔲 **Contract tests (Pact)** — consumer-driven contract test: service-dashboard asserts service-a `/orders` response schema; breaks CI if service-a changes the contract
- 🔲 **Steady-state hypothesis** — define normal operating conditions (error rate < 1%, P95 < 200ms) in code; verify chaos scenarios recover to steady state within SLO window
- 🔲 **Gameday runbook** — document a step-by-step gameday scenario: inject fault → alert fires → AI SRE responds → runbook pulled from ChromaDB → fix applied → verify recovery

---

## 16. DORA Metrics & Continuous Improvement

> Industry benchmark: **Elite teams** deploy on-demand (multiple times/day), lead time < 1h, MTTR < 1h, change failure rate < 5%.

- 🔲 **Deployment frequency tracker** — count Codefresh `promote_production` runs per week; log to a Prometheus counter via webhook
- 🔲 **Lead time for changes** — record `git commit timestamp` → `promote_production timestamp`; expose as Grafana annotation
- 🔲 **MTTR tracker** — time from alert fire to Alertmanager resolve; Loki query on `alertname` + `resolved` log entries
- 🔲 **Change failure rate** — count rollbacks (re-promotion of previous image tag) vs total deploys; track as ratio

---

## 17. Modern Market Nice-to-Haves (Research Reference)

These are things seen across well-regarded OSS GitOps projects and enterprise SRE platforms in 2025–2026. Pick and implement as interest / time allows.

| Item | Why it's trending | Effort |
|------|------------------|--------|
| **OpenTelemetry Collector** (standalone) | Replace Alloy for traces; CNCF standard, rich processors/exporters | Medium |
| **Cilium + eBPF** | Replace `kube-proxy`, eBPF network policy, Hubble for L3/L7 flow observability | High |
| **Tetragon** | eBPF-based runtime security (syscall-level), integrates with Falco | High |
| **Pyroscope / Phlare** continuous profiling | 4th observability signal after metrics/logs/traces; flame graphs in Grafana | Medium |
| **Kubernetes Gateway API** | Post-2024 Ingress replacement; `HTTPRoute`, `GatewayClass` — Gateway API is GA | Medium |
| **ArgoCD ApplicationSet + pull-request generator** | Ephemeral PR environments without any infra change | Medium |
| **vCluster** | Lightweight virtual Kubernetes clusters inside k3d — multi-tenant ephemeral envs | Medium |
| **FluxCD** side-by-side | Compare Flux vs ArgoCD on the same repo; Flux is GitOps toolkit-first, ArgoCD is UI-first | Low |
| **OpenCost / Kubecost** | Real-time per-namespace/pod cost breakdown from Prometheus metrics | Low |
| **Backstage** developer portal | Internal developer platform standard; service catalog, TechDocs, scaffolder | High |
| **Port.io** | Lighter Backstage alternative; real-time k8s entity sync | Medium |
| **Sloth / Pyrra** SLO management | Declarative SLO definitions → multi-window burn-rate Prometheus alerts auto-generated | Low |
| **Goldilocks (VPA recommender)** | Shows right-sizing recommendations per deployment in a UI | Low |
| **Robusta** | Kubernetes alert enrichment + auto-remediation playbooks | Medium |
| **Keptn / Flagger** | Automated canary analysis + deployment promotion without Argo Rollouts | Medium |
| **Dagger** CI pipelines | Portable CI written in Go/Python/TypeScript — runs same pipeline locally and in GitHub Actions | Medium |
| **OpenSSF Scorecard** | Supply chain security score (authed deps, signed commits, code review hygiene) | Low |
| **OWASP Dependency-Track** | SBOM vulnerability management centralised dashboard | Medium |

---

## Quick Pick List (highest value, lowest effort)

If you want to implement one item right now, these give the best return:

1. 🟩 `make` targets — `make cluster-up`, `make demo-phase1`, `make test` (30 min)  
2. 🟩 Kyverno policy: no `latest` image tags + resource limits required (1h)  
3. 🟩 ArgoCD Notifications → Slack on sync failure (1h)  
4. 🟩 `pre-commit` hooks — `golangci-lint` + `detect-secrets` locally (30 min)  
5. 🟩 Sloth SLO definitions → auto-generated burn-rate alerts (1–2h)  
6. 🟩 Renovate bot — automated dependency PRs (30 min, just add `renovate.json`)  
7. 🟩 OpenCost — drop-in Prometheus-based cost dashboard (1h, single helm install)  
8. 🟩 Devcontainer — GitHub Codespaces-ready `.devcontainer.json` (30 min)  
9. 🟩 LLM incident endpoint + Ollama — the most demo-able AI SRE piece (2–3h)  
10. 🟩 Argo Rollouts canary for service-a — classic GitOps progression demo (2–3h)

---

*Last updated: April 2026. Add new items to the relevant section — keep statuses current.*
