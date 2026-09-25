#!/usr/bin/env bash
# KubeForge — LAB 02 (TLS): valida o desafio.
#
# Roda contra o SEU cluster (KUBECONFIG apontando pro k3s do lab-01). Não hardcoda
# o hostname — ele é lido do próprio Ingress, então funciona para qualquer aluno.
#
#   export KUBECONFIG=~/.kube/config-kubeforge
#   ./tests/verify.sh
#
# Sai 0 se o TLS está válido em prod; 1 listando o que falta.

source "$(cd "$(dirname "$0")/../.." && pwd)/.ci/verify-lib.sh"

require_cmd kubectl

echo "== LAB 02 — Certificado TLS =="

# 1) cert-manager instalado e rodando
check "cert-manager instalado (deployment)" \
  kubectl -n cert-manager get deploy cert-manager

# 2) os dois ClusterIssuers existem e estão Ready
for issuer in letsencrypt-staging letsencrypt-prod; do
  ready=$(kubectl get clusterissuer "$issuer" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  check_eq "ClusterIssuer $issuer Ready" "${ready:-<ausente>}" "True"
done

# 3) o certificado whoami-tls foi emitido (Ready=True)
cert_ready=$(kubectl get certificate whoami-tls \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
check_eq "Certificate whoami-tls Ready" "${cert_ready:-<ausente>}" "True"

# 4) o Ingress usa o issuer de PROD (não ficou parado no staging)
issuer_ann=$(kubectl get ingress whoami \
  -o jsonpath='{.metadata.annotations.cert-manager\.io/cluster-issuer}' 2>/dev/null)
check_eq "Ingress aponta para letsencrypt-prod" "${issuer_ann:-<ausente>}" "letsencrypt-prod"

# 5) o cert emitido é de PROD, não do STAGING — o discriminador definitivo.
#    Deriva o host do próprio Ingress (não hardcoda kubeforge-mwl).
host=$(kubectl get ingress whoami \
  -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
if [ -n "$host" ] && command -v openssl >/dev/null 2>&1; then
  issuer_cn=$(echo | openssl s_client -connect "${host}:443" -servername "$host" 2>/dev/null \
    | openssl x509 -noout -issuer 2>/dev/null)
  check_contains "Cert emitido pela Let's Encrypt (não STAGING)" "$issuer_cn" "Let's Encrypt"
  # se contiver STAGING, o check_contains acima ainda passaria; então nega explicitamente:
  case "$issuer_cn" in
    *STAGING*|*"(STAGING)"*) echo "❌ Cert ainda é STAGING  ($issuer_cn)"; _KF_FAIL=$((_KF_FAIL+1)) ;;
  esac
else
  echo "⚠️  pulei o check de issuer via openssl (host vazio ou openssl ausente)"
fi

# 6) HTTPS responde sem -k (cadeado válido), do lado de fora
if [ -n "$host" ] && command -v curl >/dev/null 2>&1; then
  code=$(curl -sS -m 10 -o /dev/null -w '%{http_code}' "https://${host}/" 2>/dev/null || echo TIMEOUT)
  check_eq "HTTPS ${host} responde 200 (sem -k)" "$code" "200"
fi

summary
