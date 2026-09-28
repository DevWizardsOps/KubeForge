#!/usr/bin/env bash
# ============================================================================
# setup-auth.sh — gera a senha de login do GIRUS e cria os Secrets no cluster
# ----------------------------------------------------------------------------
# Rode ANTES de 'kubectl apply -f 02-girus-ingress.yaml' e '03-girus-auth.yaml'.
#
# O que faz:
#   1. Gera uma senha aleatória forte (32 hex = 128 bits).
#   2. Cria o Secret 'girus-basic-auth'    -> usuario:hash-bcrypt (formato
#      htpasswd) — é o que o Traefik basic-auth consome.
#   3. Cria o Secret 'girus-auth-password' -> a senha em TEXTO, pra você (ou o
#      aluno) recuperar depois com kubectl.
#   4. Imprime o comando de recuperar a senha (o mesmo que aparece na tela).
#
# Uso:
#   ./setup-auth.sh                 # usuario 'girus', senha aleatoria
#   ./setup-auth.sh -u marcelo      # outro usuario
#   ./setup-auth.sh -u girus -p 'minhaSenha'   # senha fixa (nao recomendado)
#
# Idempotente: reexecutar REGENERA a senha (novo Secret). Avisa antes.
# ============================================================================
set -euo pipefail

NS="girus"
USER="girus"
PASS=""
AUTH_SECRET="girus-basic-auth"
PASS_SECRET="girus-auth-password"

while getopts "u:p:n:" opt; do
  case "$opt" in
    u) USER="$OPTARG" ;;
    p) PASS="$OPTARG" ;;
    n) NS="$OPTARG" ;;
    *) echo "uso: $0 [-u usuario] [-p senha] [-n namespace]"; exit 1 ;;
  esac
done

command -v kubectl >/dev/null || { echo "ERRO: kubectl nao encontrado no PATH."; exit 1; }

# 1) senha aleatoria se nao veio via -p
if [[ -z "$PASS" ]]; then
  if command -v openssl >/dev/null; then
    PASS="$(openssl rand -hex 16)"
  else
    PASS="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  fi
fi

# 2) hash bcrypt no formato htpasswd (usuario:hash) — tenta htpasswd, depois python
make_htpasswd() {
  if command -v htpasswd >/dev/null; then
    htpasswd -nbB "$USER" "$PASS"        # -B = bcrypt
  elif command -v python3 >/dev/null && python3 -c "import bcrypt" 2>/dev/null; then
    python3 - "$USER" "$PASS" <<'PY'
import sys, bcrypt
u, p = sys.argv[1], sys.argv[2]
print(f"{u}:{bcrypt.hashpw(p.encode(), bcrypt.gensalt()).decode()}")
PY
  else
    echo "__NO_HASHER__"
  fi
}

HTPASSWD_LINE="$(make_htpasswd)"
if [[ "$HTPASSWD_LINE" == "__NO_HASHER__" ]]; then
  cat >&2 <<'EOF'
ERRO: preciso de 'htpasswd' (pacote apache2-utils/httpd-tools) OU do modulo
python 'bcrypt' para gerar o hash da senha.
  macOS:  brew install httpd            # traz o htpasswd
  Debian: apt-get install apache2-utils
  ou:     pip3 install bcrypt
EOF
  exit 1
fi

echo ">> namespace: $NS   usuario: $USER"

# aviso se ja existir (regeneracao)
if kubectl -n "$NS" get secret "$AUTH_SECRET" >/dev/null 2>&1; then
  echo ">> AVISO: o Secret '$AUTH_SECRET' ja existe — vou SOBRESCREVER (nova senha)."
fi

# 3) Secret consumido pelo Traefik (chave 'users' no formato htpasswd)
kubectl -n "$NS" create secret generic "$AUTH_SECRET" \
  --from-literal=users="$HTPASSWD_LINE" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4) Secret com a senha em texto, pra recuperar depois
kubectl -n "$NS" create secret generic "$PASS_SECRET" \
  --from-literal=username="$USER" \
  --from-literal=password="$PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

RECOVER_CMD="kubectl -n $NS get secret $PASS_SECRET -o jsonpath='{.data.password}' | base64 -d; echo"

cat <<EOF

============================================================
 GIRUS — login criado com sucesso
============================================================
 Usuario: $USER
 Senha:   $PASS
 (guardada no Secret '$PASS_SECRET' no namespace '$NS')

 Para recuperar a senha depois, no cluster:
   $RECOVER_CMD

 Agora (com o cert TLS já Ready) aplique o Middleware e LIGUE o auth:
   kubectl apply -f 03-girus-auth.yaml
   kubectl -n $NS annotate ingress girus-frontend \\
     traefik.ingress.kubernetes.io/router.middlewares=$NS-girus-basic-auth@kubernetescrd --overwrite

 Acesse: https://girus.<seu-host>  (o browser vai pedir usuario/senha)
============================================================
EOF
