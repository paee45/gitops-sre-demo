# GitOps-Driven SRE Demo

A production-representative SRE demo on a **single AWS EC2 instance** (Debian 12, t3.medium).  
Infrastructure is managed by Terraform, application state is managed by ArgoCD (App of Apps), and observability is the full **LGTM stack** (Loki · Grafana · Tempo · Mimir) collected by Grafana Alloy.

```
GitHub Push
    │
    ├─ .github/workflows/pipeline.yml ──► Terraform apply  ──► EC2 (t3.medium)
    │                                                              │
    └─ .github/workflows/build-images.yml ─► GHCR images         │
                                                                   ▼
                          ArgoCD (App of Apps) ◄── git pull ───── K3s
                               │
                    ┌──────────┼──────────┐
                    ▼          ▼          ▼
                  LGTM        Alloy    service-a / service-b
             (Loki·Mimir   (DaemonSet)   (Go HTTP + worker)
              Tempo·Grafana)
```

---

## Architecture

| Layer | Component | Notes |
|---|---|---|
| Cloud | AWS EC2 t3.medium (4 GB) | Debian 12, gp3 30 GB, IMDSv2 |
| Orchestrator | K3s (latest) | Traefik + servicelb disabled |
| GitOps | ArgoCD 3.3.6 | App of Apps, NodePort 32080 |
| Metrics | Grafana Mimir | monolithic mode, 7d retention |
| Logs | Grafana Loki | SingleBinary, 7d retention |
| Traces | Grafana Tempo | OTLP gRPC+HTTP, 7d retention |
| Dashboards | Grafana 12 | 7 pre-wired dashboards |
| Collector | Grafana Alloy | DaemonSet, River config |
| Services | service-a (HTTP) | orders API, Prometheus + OTLP |
| Services | service-b (worker) | background jobs, Prometheus + OTLP |
| CI | GitHub Actions | OIDC → AWS, GHCR images |
| IaC | Terraform | S3+DynamoDB backend, OIDC provider |

---

## Prerequisites

- AWS account with permission to create EC2, IAM, S3, DynamoDB, OIDC providers
- Terraform ≥ 1.7
- AWS CLI configured locally (for the bootstrap `terraform apply`)
- GitHub repository (fork or create from this project)
- S3 bucket + DynamoDB table for Terraform state (create once manually)

---

## Bootstrap Sequence

### 1 — Create Terraform state backend

```bash
aws s3api create-bucket --bucket my-tf-state --region us-east-1
aws s3api put-bucket-versioning --bucket my-tf-state \
    --versioning-configuration Status=Enabled
aws dynamodb create-table \
    --table-name my-tf-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

### 2 — Replace placeholder org/repo name

```bash
# Run from the repo root
grep -rl 'YOUR-GITHUB-ORG' . | xargs sed -i 's/YOUR-GITHUB-ORG/myorg/g'
grep -rl 'YOUR-REPO-NAME'  . | xargs sed -i 's/YOUR-REPO-NAME/gitops-sre-demo/g'
```

### 3 — Configure Terraform variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your values
```

Required fields:

```hcl
aws_region            = "us-east-1"
key_name              = "your-ec2-keypair"
allowed_ssh_cidr      = ["1.2.3.4/32"]   # your IP
github_org            = "myorg"
github_repo           = "gitops-sre-demo"
tf_state_bucket       = "my-tf-state"
tf_state_dynamodb_table = "my-tf-locks"
```

### 4 — First apply (local, creates OIDC provider + IAM role)

```bash
cd terraform
terraform init \
  -backend-config="bucket=my-tf-state" \
  -backend-config="key=gitops-sre-demo/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=my-tf-locks"

terraform apply
```

This creates the GitHub OIDC provider and the IAM role. The role ARN is printed as an output.

### 5 — Set GitHub secret

```
GitHub repo → Settings → Secrets and variables → Actions → New repository secret

Name:  AWS_ROLE_ARN
Value: <iam_role_arn from terraform output>
```

Also set these secrets/variables:

| Name | Type | Value |
|---|---|---|
| `AWS_ROLE_ARN` | Secret | IAM role ARN from step 4 |
| `TF_STATE_BUCKET` | Variable | your S3 bucket name |
| `TF_STATE_DYNAMODB` | Variable | your DynamoDB table name |

### 6 — Push to main

Any push to `main` that touches `terraform/**` will trigger the Terraform workflow.  
Any push that touches `src/**` will trigger the image build and push to GHCR.

After the first full apply the EC2 instance boots, installs K3s, installs ArgoCD, and applies the root App of Apps. All LGTM components and microservices are then synced by ArgoCD.

---

## Accessing the Demo

Once `terraform apply` completes, run:

```bash
terraform -chdir=terraform output
```

| Output | Value |
|---|---|
| `grafana_url` | `http://<public-ip>:3000` |
| `argocd_url` | `http://<public-ip>:32080` |
| `ssh_command` | `ssh admin@<public-ip> -i <key>` |

### Grafana

- URL: `http://<public-ip>:3000`
- Login: anonymous Viewer access (no credentials needed for demo)
- All 7 dashboards are auto-provisioned under **Dashboards → Browse**

### ArgoCD

- URL: `http://<public-ip>:32080`
- Username: `admin`
- Password: retrieve with:

```bash
ssh admin@<ip> 'kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d'
```

---

## Pre-wired Grafana Dashboards

| Dashboard | gnetId | What it shows |
|---|---|---|
| Kubernetes / Compute Resources / Cluster | 6417 | Cluster-wide CPU, memory, network |
| Kubernetes / Nodes | 8171 | Per-node resource usage |
| cAdvisor Metrics | 14282 | Container-level CPU + memory |
| Loki / Logs | 14055 | Log volume + log explorer |
| Go RED Metrics | 10127 | Rate, Errors, Duration for Go services |
| ArgoCD | 14584 | Sync status, app health |
| Tempo / Distributed Tracing | 19689 | Trace search + latency heatmap |

Trace-to-logs and trace-to-metrics correlation is configured. Click a trace span in Tempo to jump directly to the correlated Loki log stream.

---

## Observability Signal Flow

```
service-a / service-b
    │
    ├── /metrics (Prometheus exposition) ◄── Alloy pod annotation scrape
    │                                              │
    │                                              ▼
    │                                         Mimir (remote_write)
    │
    ├── stdout (JSON via slog) ◄── Alloy loki.source.file
    │                                              │
    │                                              ▼
    │                                         Loki (push)
    │
    └── OTLP HTTP :4318 ──► Alloy otelcol receiver
                                          │
                                          ▼
                                     Tempo (OTLP gRPC)
```

Alloy also scrapes kubelet cAdvisor on every node and forwards to Mimir.

---

## Memory Budget (t3.medium, 4 GB)

| Component | Request | Limit |
|---|---|---|
| K3s + system | ~500 MB | — |
| ArgoCD (all pods) | ~300 MB | ~512 MB |
| Loki | ~256 MB | ~512 MB |
| Mimir | ~384 MB | ~768 MB |
| Tempo | ~192 MB | ~384 MB |
| Grafana | ~128 MB | ~256 MB |
| Alloy | ~128 MB | ~256 MB |
| service-a + service-b | ~64 MB | ~128 MB |
| **Total requests** | **~1.95 GB** | **~2.8 GB** |

A 3 GB swapfile (`vm.swappiness=30`) provides headroom during cold starts. If you hit OOM during a live demo, upgrade with:

```hcl
# terraform.tfvars
instance_type = "t3.large"  # 8 GB
```

Then `terraform apply` — the instance is replaced (EBS is preserved for state).

---

## Cost Estimate

| Resource | Monthly cost (approx) |
|---|---|
| t3.medium (on-demand, us-east-1) | ~$30 |
| gp3 30 GB EBS | ~$2.40 |
| Data transfer (minimal) | ~$1 |
| **Total** | **~$33/mo** |

Stop the instance when not demoing to reduce costs.  
Destroy when done: `terraform destroy`.

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── pipeline.yml          # Terraform plan + apply (OIDC)
│       └── build-images.yml      # Build + push Go images to GHCR
├── argocd/
│   └── root-app.yaml             # App of Apps root application
├── k8s/
│   ├── observability/
│   │   ├── loki/                 # Loki app.yaml + values.yaml
│   │   ├── mimir/                # Mimir app.yaml + values.yaml
│   │   ├── tempo/                # Tempo app.yaml + values.yaml
│   │   ├── grafana/              # Grafana app.yaml + values.yaml
│   │   └── alloy/                # Alloy app.yaml + values.yaml + config.alloy
│   └── apps/
│       ├── service-a/            # ArgoCD app + K8s manifests
│       └── service-b/            # ArgoCD app + K8s manifests
├── src/
│   ├── service-a/                # Go HTTP API simulator
│   │   ├── main.go
│   │   ├── go.mod
│   │   └── Dockerfile
│   └── service-b/                # Go background worker simulator
│       ├── main.go
│       ├── go.mod
│       └── Dockerfile
└── terraform/
    ├── main.tf                   # EC2, OIDC, IAM, SG
    ├── variables.tf
    ├── outputs.tf
    ├── user-data.sh              # K3s + ArgoCD bootstrap
    └── terraform.tfvars.example
```

---

## Idempotency

`user-data.sh` is fully idempotent:
- Swap creation is guarded by a file-existence check
- K3s install uses the official idempotent installer (re-running is safe)
- ArgoCD is installed via `helm upgrade --install --atomic --wait`
- The root App of Apps is applied with `kubectl apply`

Re-running `terraform apply` with `user_data_replace_on_change = true` will replace the instance only if the user-data template changes. Instance type changes also trigger replacement.
