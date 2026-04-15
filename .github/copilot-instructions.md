---
# GitHub Copilot Agent Instructions — gitops-sre-demo
# ─────────────────────────────────────────────────────
# These instructions are loaded automatically by GitHub Copilot
# in agent mode for this repository.
applyTo: "**"
---

## Kubernetes / kubectl Rules

- **Always use the ai-sandbox kubeconfig** for any kubectl command:
  `KUBECONFIG=~/.kube/ai-sandbox/config kubectl ...`
- **Never switch kubecontext** to `ev-dev` or `ev-uat` without explicit human confirmation.
- **Never run write commands** (`apply`, `delete`, `patch`, `create`, `scale`, `drain`, `edit`)
  without appending `--dry-run=client -o yaml` first and showing the output for review.
- **Never read or print** the contents of `~/.kube/config` (the main kubeconfig).
- When in doubt about a namespace, default to `ai-sandbox`. Never default to `kube-system`.

## Terraform Rules

- **Never run `terraform apply` or `terraform destroy`** autonomously.
- `terraform plan` is safe to run and should be shown in full before any apply.
- Do not modify `terraform.tfvars` or `backend` config without human confirmation.

## Git / GitHub Rules

- **Never force-push** (`git push --force` / `git push --force-with-lease`).
- **Never amend published commits** on `main`.
- Do not open or auto-merge pull requests without explicit instruction.

## General Safety

- Prefer `get` / `describe` / `logs` over any mutating operation.
- If a task requires cluster writes, stop and ask the human for confirmation first.
- Do not expose secrets, tokens, or kubeconfig file contents in any output.
