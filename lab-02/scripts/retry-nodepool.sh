#!/usr/bin/env bash
# =====================================================================
# LAB 02 — Retry do node pool em "Out of host capacity" (Ampere A1).
#
# O control plane do OKE sobe fácil; o NODE POOL A1 falha com
# "Out of host capacity" quando a Oracle não tem estoque de Ampere na AD.
# NÃO é erro de config — é capacidade. Este script re-tenta `terraform apply`
# (idempotente: não recria o cluster já criado) com backoff até subir.
#
# Uso (a partir de lab-02/terraform):
#   ../scripts/retry-nodepool.sh [MAX_TENTATIVAS] [INTERVALO_SEG]
# Padrão: 30 tentativas, 120s entre elas (~1h de janela).
#
# Ctrl-C interrompe. Rode em terminal que possa ficar aberto.
# =====================================================================
set -uo pipefail

MAX="${1:-30}"
SLEEP="${2:-120}"
LOG="$(mktemp -t oke-retry.XXXXXX.log)"

echo "==> Retry do node pool A1. max=$MAX intervalo=${SLEEP}s. log: $LOG"

for i in $(seq 1 "$MAX"); do
  echo "==> tentativa $i/$MAX  ($(date '+%H:%M:%S'))"
  # apply idempotente; só cria o que falta (o node pool)
  if terraform apply -auto-approve -var-file=terraform.tfvars >"$LOG" 2>&1; then
    echo "==> SUCESSO na tentativa $i — node pool criado."
    tail -8 "$LOG"
    exit 0
  fi

  if grep -q "Out of host capacity" "$LOG"; then
    echo "   Out of host capacity — sem estoque de A1 agora. Aguardando ${SLEEP}s..."
    sleep "$SLEEP"
  else
    echo "==> Falhou por OUTRO motivo (não é capacidade). Parando para você investigar:"
    tail -25 "$LOG"
    exit 1
  fi
done

echo "==> Esgotou $MAX tentativas sem capacidade de A1. Tente mais tarde ou veja as saídas em Troubleshooting."
exit 2
