#!/usr/bin/env bash
# KubeForge — biblioteca de checagem de labs (verify-lib.sh)
#
# O "check script" de cada lab (tests/verify.sh) faz `source` deste arquivo e usa
# os helpers abaixo. É o mesmo papel do check script do Instruqt — "o aluno
# resolveu?" — mas versionado no repo, custo zero, rodando no seu próprio cluster.
#
# Uso no verify.sh do lab:
#   source "$(dirname "$0")/../../.ci/verify-lib.sh"
#   check "server responde"  kubectl get --raw='/readyz'
#   check_eq "3 nós Ready"    "$(kubectl get nodes --no-headers | grep -c ' Ready ')" 3
#   summary   # imprime o placar e sai 0 (tudo ✅) ou 1 (algum ❌)
#
# Convenção: cada check imprime "✅ <nome>" ou "❌ <nome>  (motivo)".

set -uo pipefail

_KF_PASS=0
_KF_FAIL=0

# check "<nome>" <comando...>  → passa se o comando sai 0
check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "✅ $name"; _KF_PASS=$((_KF_PASS+1))
  else
    echo "❌ $name  (comando falhou: $*)"; _KF_FAIL=$((_KF_FAIL+1))
  fi
}

# check_eq "<nome>" "<valor>" "<esperado>"  → passa se iguais
check_eq() {
  local name="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    echo "✅ $name"; _KF_PASS=$((_KF_PASS+1))
  else
    echo "❌ $name  (esperado '$want', obtido '$got')"; _KF_FAIL=$((_KF_FAIL+1))
  fi
}

# check_contains "<nome>" "<texto>" "<substring>"  → passa se substring ∈ texto
check_contains() {
  local name="$1" hay="$2" needle="$3"
  case "$hay" in
    *"$needle"*) echo "✅ $name"; _KF_PASS=$((_KF_PASS+1)) ;;
    *) echo "❌ $name  ('$needle' não encontrado)"; _KF_FAIL=$((_KF_FAIL+1)) ;;
  esac
}

# require_cmd <bin>...  → aborta cedo se uma ferramenta essencial falta
require_cmd() {
  local missing=0
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || { echo "⚠️  falta a ferramenta: $c"; missing=1; }
  done
  [ "$missing" -eq 0 ] || { echo "Instale as ferramentas acima e rode de novo."; exit 2; }
}

# summary  → placar final + exit code (0 tudo ok, 1 algum falhou)
summary() {
  echo "────────────────────────────────"
  echo "Resultado: ${_KF_PASS} ✅   ${_KF_FAIL} ❌"
  if [ "$_KF_FAIL" -eq 0 ]; then
    echo "🎉 Lab validado — todos os checks passaram."
    exit 0
  else
    echo "Ainda falta: reveja os ❌ acima. (Cada um diz o que era esperado.)"
    exit 1
  fi
}
