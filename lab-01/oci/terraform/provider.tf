# =====================================================================
# LAB 01 — OCI Foundation :: Provider
# Autenticação via API Key lida de ~/.oci/config (perfil DEFAULT) ou das
# variáveis. NENHUMA credencial fica em código. Ver README.md e
# ../docs/account-setup/ para como obter tenancy/user OCID, fingerprint
# e a private key.
# =====================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.0" # major 9 (9.2.0 é o mais recente em 2026-09); patches/minors liberados
    }
  }

  # Backend local por padrão (state fora do Git — coberto pelo .gitignore).
  # Para o LAB 02 em diante, avaliar backend remoto (OCI Object Storage / S3-compat).
  # backend "local" {}
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
