#!/usr/bin/env bash
# ============================================================================
# verify.sh — valida a plataforma GIRUS on k3s (Fase 1 da trilha)
# ============================================================================
# Checa que o backend/frontend subiram, o Ingress + cert TLS estão prontos e o
# frontend responde HTTPS no hostname dedicado (girus-<iniciais>).
#
# Uso:
#   export KUBECONFIG=~/.kube/config-kubeforge
#   ./tests/verify.sh
# ============================================================================
set -uo pipefail

# Carrega os helpers compartilhados (check, check_eq, check_contains, summary).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/../../../.ci/verify-lib.sh"

NS="girus"

# 1. Namespace existe
check "namespace '$NS' existe" \
  kubectl get ns "$NS"

# 2. Backend e frontend disponíveis (rollout completo)
check "deployment girus-backend disponível" \
  kubectl -n "$NS" rollout status deploy/girus-backend --timeout=5s
check "deployment girus-frontend disponível" \
  kubectl -n "$NS" rollout status deploy/girus-frontend --timeout=5s

# 3. Services existem
check "service girus-backend existe" \
  kubectl -n "$NS" get svc girus-backend
check "service girus-frontend existe" \
  kubectl -n "$NS" get svc girus-frontend

# 4. Ingress existe e tem host definido — o host é LIDO do próprio Ingress,
#    então funciona para qualquer aluno sem editar este script.
HOST="$(kubectl -n "$NS" get ingress girus-frontend \
        -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)"
check_contains "ingress girus-frontend tem host girus.*" "$HOST" "girus."

# 5. Certificado TLS emitido e pronto
check_eq "certificado girus-frontend-tls READY=True" \
  "$(kubectl -n "$NS" get certificate girus-frontend-tls \
     -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" \
  "True"

# 6. Autenticação de borda ATIVA: sem credencial o Ingress responde 401.
if [ -n "$HOST" ]; then
  check "https://$HOST exige login (401 sem credencial)" \
    bash -c "curl -sS -o /dev/null -w '%{http_code}' https://$HOST | grep -q '^401$'"

  # 7. Com a credencial do Secret, o frontend responde 200 (cert válido, sem -k).
  AUTH_USER="$(kubectl -n "$NS" get secret girus-auth-password \
               -o jsonpath='{.data.username}' 2>/dev/null | base64 -d 2>/dev/null)"
  AUTH_PASS="$(kubectl -n "$NS" get secret girus-auth-password \
               -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null)"
  if [ -n "$AUTH_USER" ] && [ -n "$AUTH_PASS" ]; then
    check "https://$HOST responde 200 autenticado (cert válido, sem -k)" \
      bash -c "curl -fsS -u '$AUTH_USER:$AUTH_PASS' -o /dev/null -w '%{http_code}' https://$HOST | grep -q '^200$'"
  else
    check "credencial no Secret girus-auth-password" bash -c "false"  # rode setup-auth.sh
  fi
else
  check "https no host do Girus" bash -c "false"  # sem host, falha explícita
fi

summary
