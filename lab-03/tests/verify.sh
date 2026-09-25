#!/usr/bin/env bash
# KubeForge — LAB 03 (Helm): valida o desafio.
#
#   export KUBECONFIG=~/.kube/config-kubeforge
#   ./tests/verify.sh
#
# Assume o release instalado com o nome 'whoami' (helm install whoami ./charts/whoami).
# Sai 0 se o chart está deployed com os pods no ar; 1 listando o que falta.

source "$(cd "$(dirname "$0")/../.." && pwd)/.ci/verify-lib.sh"

require_cmd kubectl helm

RELEASE="${1:-whoami}"
echo "== LAB 03 — Helm (release: $RELEASE) =="

# 1) o release existe e está 'deployed'
status=$(helm status "$RELEASE" -o json 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
check_eq "release '$RELEASE' está deployed" "${status:-<ausente>}" "deployed"

# 2) o Deployment criado pelo chart existe e tem réplicas prontas
want=$(helm get values "$RELEASE" -a -o json 2>/dev/null | grep -o '"replicaCount":[0-9]*' | cut -d: -f2)
want="${want:-2}"
ready=$(kubectl get deploy "$RELEASE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
check_eq "Deployment $RELEASE com ${want} réplicas prontas" "${ready:-0}" "$want"

# 3) o Service do chart existe
check "Service $RELEASE existe" kubectl get svc "$RELEASE"

# 4) os labels padrão do Helm foram aplicados (prova que veio do chart, não de YAML solto)
managed=$(kubectl get deploy "$RELEASE" \
  -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null)
check_eq "Deployment gerenciado pelo Helm" "${managed:-<ausente>}" "Helm"

# 5) houve pelo menos 1 upgrade (revisão >= 2) — prova o ciclo install->upgrade
rev=$(helm history "$RELEASE" -o json 2>/dev/null | grep -o '"revision":[0-9]*' | tail -1 | cut -d: -f2)
if [ "${rev:-0}" -ge 2 ]; then
  echo "✅ release passou por upgrade (revisão atual: $rev)"; _KF_PASS=$((_KF_PASS+1))
else
  echo "⚠️  revisão atual: ${rev:-0} — faça um 'helm upgrade' (ex: --set replicaCount=3) para exercitar o ciclo"
fi

summary
