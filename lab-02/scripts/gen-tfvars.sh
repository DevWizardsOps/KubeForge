#!/usr/bin/env bash
# =====================================================================
# LAB 02 — Gera terraform.tfvars puxando os OUTPUTS de rede do LAB 01.
#
# Uso:
#   cd lab-02/terraform && ../scripts/gen-tfvars.sh
#
# O que faz:
#   1. cp example.tfvars terraform.tfvars (se ainda não existir)
#   2. lê vcn_id / public_subnet_id / private_subnet_id do state do LAB 01
#      via `terraform output -raw` (não faz parse frágil de texto)
#   3. substitui os placeholders no terraform.tfvars (sed portátil macOS/Linux)
#
# NÃO toca na AUTH (tenancy/user/fingerprint/key): preencha à mão OU use ~/.oci/config.
# terraform.tfvars é ignorado pelo git.
# =====================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/terraform"   # lab-02/terraform
LAB01_TF="$(cd "$HERE/../../lab-01/terraform" && pwd)"
TFVARS="$HERE/terraform.tfvars"
EXAMPLE="$HERE/example.tfvars"

echo "==> LAB 01 terraform dir: $LAB01_TF"

# 0. LAB 01 precisa ter state aplicado
if [ ! -f "$LAB01_TF/terraform.tfstate" ]; then
  echo "ERRO: $LAB01_TF/terraform.tfstate não existe. Rode 'terraform apply' no LAB 01 primeiro." >&2
  exit 1
fi

# 1. cria terraform.tfvars a partir do exemplo (preserva se já existir)
if [ ! -f "$TFVARS" ]; then
  cp "$EXAMPLE" "$TFVARS"
  echo "==> criado $TFVARS a partir de example.tfvars"
else
  echo "==> $TFVARS já existe — apenas atualizando os OCIDs de rede"
fi

# 2. lê os outputs do LAB 01 (falha limpa se algum não existir)
VCN_ID="$(terraform -chdir="$LAB01_TF" output -raw vcn_id)"
PUB_ID="$(terraform -chdir="$LAB01_TF" output -raw public_subnet_id)"
PRV_ID="$(terraform -chdir="$LAB01_TF" output -raw private_subnet_id)"

echo "==> vcn_id            = $VCN_ID"
echo "==> public_subnet_id  = $PUB_ID"
echo "==> private_subnet_id = $PRV_ID"

# 3. substitui no tfvars. sed -i portátil: usa backup e remove (macOS exige sufixo).
sed_inplace() { sed -i.bak "$1" "$TFVARS" && rm -f "$TFVARS.bak"; }

sed_inplace "s|^vcn_id .*|vcn_id            = \"$VCN_ID\"|"
sed_inplace "s|^public_subnet_id .*|public_subnet_id  = \"$PUB_ID\"|"
sed_inplace "s|^private_subnet_id .*|private_subnet_id = \"$PRV_ID\"|"

echo "==> OCIDs de rede gravados em $TFVARS"
echo "==> LEMBRE de preencher a AUTH (tenancy/user/fingerprint) ou usar ~/.oci/config."
echo "==> próximos: terraform init && terraform plan -var-file=terraform.tfvars"
