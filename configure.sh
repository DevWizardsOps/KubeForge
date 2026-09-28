#!/usr/bin/env bash
# ============================================================================
# configure.sh — materializa os manifests com o SEU hostname (KUBEFORGE_HOST)
# ----------------------------------------------------------------------------
# Lê KUBEFORGE_HOST (de kubeforge.env, do ambiente, ou de -h) e substitui o
# placeholder __KUBEFORGE_HOST__ nos manifests que precisam do hostname,
# gerando cópias *.rendered.yaml (gitignored). Você aplica os .rendered:
#
#   cp kubeforge.env.example kubeforge.env   # e preencha KUBEFORGE_HOST
#   ./configure.sh
#   kubectl apply -f platform/girus-on-k3s/02-girus-ingress.rendered.yaml
#   kubectl apply -f lab-02/manifests/03-whoami-ingress.rendered.yaml
#
# Assim os arquivos VERSIONADOS ficam com o placeholder (nada de hostname de
# ninguém commitado) e o git não fica sujo. Reexecutar é idempotente.
#
# Uso:
#   ./configure.sh                          # lê KUBEFORGE_HOST de kubeforge.env/env
#   ./configure.sh -h kubeforge-abc.dom.com # passa o host direto
#   KUBEFORGE_HOST=... ./configure.sh
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# host via -h, senão do ambiente, senão de kubeforge.env
HOST="${KUBEFORGE_HOST:-}"
while getopts "h:" opt; do
  case "$opt" in
    h) HOST="$OPTARG" ;;
    *) echo "uso: $0 [-h kubeforge-<iniciais>.<seu-dominio>]"; exit 1 ;;
  esac
done

if [[ -z "$HOST" && -f "$ROOT/kubeforge.env" ]]; then
  # shellcheck source=/dev/null
  . "$ROOT/kubeforge.env"
  HOST="${KUBEFORGE_HOST:-}"
fi

if [[ -z "$HOST" ]]; then
  cat >&2 <<'EOF'
ERRO: KUBEFORGE_HOST não definido.
  cp kubeforge.env.example kubeforge.env   # e preencha KUBEFORGE_HOST
  ./configure.sh
ou:
  ./configure.sh -h kubeforge-<iniciais>.<seu-dominio>
EOF
  exit 1
fi

# validação simples de hostname (sem https://, sem porta, sem barra)
if [[ "$HOST" =~ ^https?:// || "$HOST" == */* || "$HOST" == *:* ]]; then
  echo "ERRO: KUBEFORGE_HOST deve ser só o hostname (ex.: kubeforge-abc.dom.com), sem https://, porta ou caminho." >&2
  exit 1
fi

echo ">> KUBEFORGE_HOST = $HOST"

# manifests com placeholder __KUBEFORGE_HOST__ (relativos à raiz do repo)
TEMPLATES=(
  "platform/girus-on-k3s/02-girus-ingress.yaml"
  "lab-02/manifests/03-whoami-ingress.yaml"
)

rendered=0
for tpl in "${TEMPLATES[@]}"; do
  src="$ROOT/$tpl"
  [[ -f "$src" ]] || { echo ">> (pulando, não existe: $tpl)"; continue; }
  out="${src%.yaml}.rendered.yaml"
  sed "s|__KUBEFORGE_HOST__|$HOST|g" "$src" > "$out"
  # avisa se sobrou placeholder por engano
  if grep -q "__KUBEFORGE_HOST__" "$out"; then
    echo ">> AVISO: placeholder ainda presente em $out" >&2
  fi
  echo "   gerado: ${out#$ROOT/}"
  rendered=$((rendered+1))
done

cat <<EOF

>> $rendered manifest(s) materializado(s) com host '$HOST'.

Aplicar (exemplos):
  kubectl apply -f platform/girus-on-k3s/02-girus-ingress.rendered.yaml
  kubectl apply -f lab-02/manifests/03-whoami-ingress.rendered.yaml

Helm (LAB 03) — passe o host direto, sem placeholder:
  helm install whoami lab-03/charts/whoami --set ingress.host=$HOST
EOF
