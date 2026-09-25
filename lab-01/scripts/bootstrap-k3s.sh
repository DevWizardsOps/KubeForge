#!/usr/bin/env bash
#
# bootstrap-k3s.sh — instala/valida um cluster k3s single-node.
#
# Onde roda: DENTRO da instância EC2 do AWS Academy Learner Lab (não no seu Mac).
# Idempotente: rodar de novo após um reset de 4h reusa a instalação existente.
# Arquitetura: detecta arm64 (Graviton, ex. t4g) ou amd64 (x86, ex. t3) — o
#              instalador oficial do k3s serve os dois; a premissa ARM64 do
#              KubeForge é preferida, mas o script não quebra em x86.
#
# Uso (dentro da EC2, como usuário com sudo):
#   chmod +x bootstrap-k3s.sh
#   ./bootstrap-k3s.sh
#
set -euo pipefail

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

# --- 1. Contexto: arquitetura e distro ------------------------------------
ARCH="$(uname -m)"
case "$ARCH" in
  aarch64|arm64) ARCH_LABEL="arm64 (Graviton/ARM)";;
  x86_64|amd64)  ARCH_LABEL="amd64 (x86)"; warn "Rodando em x86 — a premissa do KubeForge é ARM64. Funciona, mas prefira uma instância Graviton (t4g/m6g) quando a SCP permitir.";;
  *) ARCH_LABEL="$ARCH (desconhecida)";;
esac
log "Arquitetura detectada: $ARCH_LABEL"

# --- 2. k3s já instalado? (idempotência pós-reset de 4h) ------------------
if command -v k3s >/dev/null 2>&1 && sudo systemctl is-active --quiet k3s 2>/dev/null; then
  log "k3s já instalado e ativo — reaproveitando (nada a fazer)."
else
  log "Instalando k3s (installer oficial)…"
  # --write-kubeconfig-mode 644: deixa o kubeconfig legível sem sudo.
  # INSTALL_K3S_EXEC 'server': single-node (control plane + worker no mesmo host).
  curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" sh -
  log "k3s instalado."
fi

# --- 3. kubeconfig para o usuário ------------------------------------------
mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
export KUBECONFIG="$HOME/.kube/config"
log "kubeconfig copiado para ~/.kube/config"

# --- 4. Espera o nó ficar Ready --------------------------------------------
log "Aguardando o nó ficar Ready…"
for i in $(seq 1 30); do
  if kubectl get nodes 2>/dev/null | grep -q ' Ready '; then break; fi
  sleep 4
done

# --- 5. Validação final ----------------------------------------------------
echo
log "Nós do cluster (confira ARCH na última coluna):"
kubectl get nodes -o wide
echo
log "Versão do k3s: $(k3s --version | head -1)"
log "Pronto. Para usar noutra sessão SSH: export KUBECONFIG=~/.kube/config"

# Nota sobre o reset de 4h do Learner Lab:
#   A EC2 PARA (stop), não é deletada — o k3s e o estado do cluster voltam ao
#   reiniciar a instância. Se a instância for RECICLADA (raro), rode este
#   script de novo: ele reinstala do zero de forma idempotente.
