# =============================================================================
# scripts/ai-shell-guard.zsh
# =============================================================================
# AI-Agent Context Security Guard for this GitOps SRE project.
#
# Source this in your ~/.zshrc:
#   source /path/to/gitops-sre-demo/scripts/ai-shell-guard.zsh
#
# What it does:
#   1. Locks ev-dev and ev-uat contexts behind a password prompt
#   2. Forces --dry-run=client -o yaml on all kubectl write commands when
#      KUBECONFIG is set to the ai-sandbox config (i.e. AI agent sessions)
#   3. Adds `kai` alias — drops into a read-only shell with the restricted
#      ai-sandbox kubeconfig pre-loaded
# =============================================================================

# ── Protected contexts (require password to switch into) ─────────────────────
_AI_GUARD_PROTECTED_CONTEXTS=("ev-dev" "ev-uat")

# Password is read from env — set this in your ~/.zshrc BEFORE sourcing this
# file, e.g.:  export KUBEPROTECT_PASSWORD="your-secret"
# Never hard-code a password here.

# ── AI sandbox kubeconfig path ───────────────────────────────────────────────
_AI_SANDBOX_KUBECONFIG="${HOME}/.kube/ai-sandbox/config"

# ── kubectl wrapper ──────────────────────────────────────────────────────────
kubectl() {
  # 1. Block switching to protected contexts without password
  if [[ "$1" == "config" && "$2" == "use-context" ]]; then
    local _target="${3:-}"
    if [[ " ${_AI_GUARD_PROTECTED_CONTEXTS[*]} " == *" ${_target} "* ]]; then
      echo "⛔  Protected kubecontext: ${_target}" >&2
      if [[ -z "${KUBEPROTECT_PASSWORD:-}" ]]; then
        echo "    Set KUBEPROTECT_PASSWORD in your shell to unlock." >&2
        return 1
      fi
      echo -n "    Password: "
      read -rs _entered_pw; echo
      if [[ "${_entered_pw}" != "${KUBEPROTECT_PASSWORD}" ]]; then
        echo "    Access denied." >&2
        unset _entered_pw
        return 1
      fi
      unset _entered_pw
    fi
  fi

  # 2. When running under the ai-sandbox kubeconfig, force dry-run on writes
  local _active_kubeconfig="${KUBECONFIG:-${HOME}/.kube/config}"
  if [[ "${_active_kubeconfig}" == *"ai-sandbox"* ]]; then
    local _write_verbs=("apply" "create" "delete" "patch" "replace" "scale"
                        "rollout" "label" "annotate" "taint" "cordon"
                        "uncordon" "drain" "edit")
    local _verb="${1:-}"
    for _wv in "${_write_verbs[@]}"; do
      if [[ "${_verb}" == "${_wv}" ]]; then
        echo "🛡️  AI sandbox: forcing --dry-run=client -o yaml (no cluster changes)" >&2
        command kubectl "$@" --dry-run=client -o yaml
        return $?
      fi
    done
  fi

  command kubectl "$@"
}

# ── kubectx wrapper (if installed) ───────────────────────────────────────────
if command -v kubectx &>/dev/null; then
  kubectx() {
    local _target="${1:-}"
    if [[ " ${_AI_GUARD_PROTECTED_CONTEXTS[*]} " == *" ${_target} "* ]]; then
      echo "⛔  Protected kubecontext: ${_target}" >&2
      if [[ -z "${KUBEPROTECT_PASSWORD:-}" ]]; then
        echo "    Set KUBEPROTECT_PASSWORD in your shell to unlock." >&2
        return 1
      fi
      echo -n "    Password: "
      read -rs _entered_pw; echo
      if [[ "${_entered_pw}" != "${KUBEPROTECT_PASSWORD}" ]]; then
        echo "    Access denied." >&2
        unset _entered_pw
        return 1
      fi
      unset _entered_pw
    fi
    command kubectx "$@"
  }
fi

# ── `kai` — AI read-only shell alias ─────────────────────────────────────────
# Opens a subshell where KUBECONFIG is pinned to the ai-sandbox restricted
# kubeconfig. Any kubectl write in this subshell is auto-dry-run'd.
#
# Usage:  kai
#         kai kubectl get pods          (single command, then exit)
alias kai='KUBECONFIG="${_AI_SANDBOX_KUBECONFIG}" zsh'

# ── Helpful one-liners ────────────────────────────────────────────────────────
alias kctx-sandbox='kubectl config use-context ai-sandbox'
alias kctx-show='kubectl config current-context'

# ── Banner (shown once per shell session) ────────────────────────────────────
if [[ -z "${_AI_GUARD_LOADED:-}" ]]; then
  export _AI_GUARD_LOADED=1
  echo "🛡️  ai-shell-guard loaded — ev-dev/ev-uat are password-protected"
  echo "    kai        → open AI read-only subshell"
  echo "    kctx-show  → show current context"
fi
