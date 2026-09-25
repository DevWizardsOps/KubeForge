#!/usr/bin/env bash
# KubeForge — LAB 01 (fundação): valida o cluster k3s ARM64.
#
#   export KUBECONFIG=~/.kube/config-kubeforge
#   ./tests/verify.sh
#
# Sai 0 se o cluster está de pé com nós ARM64 Ready e o endpoint usa o hostname DDNS.

source "$(cd "$(dirname "$0")/../.." && pwd)/.ci/verify-lib.sh"

require_cmd kubectl

echo "== LAB 01 — k3s multi-node ARM64 =="

# 1) API server responde
check "API server responde (/readyz)" kubectl get --raw=/readyz

# 2) ao menos 2 nós Ready (1 server + 1+ agent)
ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 ~ /(^|,)Ready($|,)/{c++} END{print c+0}')
if [ "${ready_nodes:-0}" -ge 2 ]; then
  echo "✅ nós Ready: ${ready_nodes} (>= 2)"; _KF_PASS=$((_KF_PASS+1))
else
  echo "❌ nós Ready: ${ready_nodes:-0}  (esperado >= 2)"; _KF_FAIL=$((_KF_FAIL+1))
fi

# 3) arquitetura ARM64 em todos os nós
arches=$(kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}' 2>/dev/null)
if [ -n "$arches" ] && ! echo "$arches" | grep -qv 'arm64'; then
  echo "✅ todos os nós são arm64 ($arches)"; _KF_PASS=$((_KF_PASS+1))
else
  echo "❌ nem todos arm64  (obtido: '${arches:-<vazio>}')"; _KF_FAIL=$((_KF_FAIL+1))
fi

# 4) o endpoint do kubeconfig usa o hostname DDNS (não um IP) — estabilidade entre sessões
server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
case "$server" in
  https://*[0-9].[0-9]*:*|https://*[0-9]*.[0-9]*.[0-9]*.[0-9]*:*)
    echo "❌ endpoint usa IP, não o hostname DDNS  ($server)"; _KF_FAIL=$((_KF_FAIL+1)) ;;
  https://*.*:*)
    echo "✅ endpoint usa hostname DDNS ($server)"; _KF_PASS=$((_KF_PASS+1)) ;;
  *)
    echo "❌ endpoint inesperado  ('${server:-<vazio>}')"; _KF_FAIL=$((_KF_FAIL+1)) ;;
esac

# 5) (opcional) o hostname resolve — só se dig existir
host=$(echo "$server" | sed -E 's#https://([^:/]+).*#\1#')
if command -v dig >/dev/null 2>&1 && [ -n "$host" ]; then
  ip=$(dig +short "$host" 2>/dev/null | tail -1)
  check "$host resolve para um IP ($ip)" test -n "$ip"
fi

summary
