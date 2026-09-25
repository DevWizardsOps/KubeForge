#!/usr/bin/env bash
#
# install-cert-manager.sh — instala o cert-manager no cluster (idempotente).
#
# Onde roda: no seu Mac (com KUBECONFIG apontando pro cluster) OU no server via SSH.
# cert-manager é o operador que pede e renova certificados ACME (Let's Encrypt).
# Imagens multi-arch — roda em ARM64 (Graviton) sem ajuste.
set -euo pipefail

CM_VERSION="v1.16.2"   # versão estável do cert-manager

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

log "Instalando cert-manager $CM_VERSION (CRDs + controlador)…"
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CM_VERSION}/cert-manager.yaml"

log "Aguardando os pods do cert-manager ficarem Ready…"
kubectl -n cert-manager rollout status deploy/cert-manager --timeout=120s
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=120s
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=120s

log "cert-manager pronto. Pods:"
kubectl -n cert-manager get pods

echo
log "Próximo: kubectl apply -f manifests/01-clusterissuers.yaml (troque o e-mail antes)"
