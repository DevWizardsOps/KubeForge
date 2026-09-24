# =====================================================================
# LAB 02 — Variáveis (OKE + Node Pool Ampere A1 ARM64)
# =====================================================================

# ---------- Autenticação OCI ----------
variable "tenancy_ocid" {
  type        = string
  description = "OCID do tenancy."
}

variable "user_ocid" {
  type        = string
  description = "OCID do usuário."
}

variable "fingerprint" {
  type        = string
  description = "Fingerprint da API Key."
}

variable "private_key_path" {
  type        = string
  description = "Caminho local da private key."
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  type        = string
  description = "Região home."
  default     = "sa-saopaulo-1"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment onde o cluster será criado. Vazio = tenancy root."
  default     = ""
}

# ---------- Rede (OUTPUTS do LAB 01) ----------
# Cole aqui os valores de `terraform output` do lab-01/terraform.
variable "vcn_id" {
  type        = string
  description = "OCID da VCN criada no LAB 01."
}

variable "public_subnet_id" {
  type        = string
  description = "OCID da subnet PÚBLICA (control plane endpoint + LBs)."
}

variable "private_subnet_id" {
  type        = string
  description = "OCID da subnet PRIVADA (worker nodes)."
}

# ---------- Nomenclatura ----------
variable "project_name" {
  type    = string
  default = "kubeforge"
}

variable "environment" {
  type    = string
  default = "lab"
}

# ---------- Kubernetes ----------
variable "kubernetes_version" {
  type        = string
  description = "Versão do OKE. Verifique as suportadas na região ANTES (README). Em 09/2026 existem 1.34.x, 1.35.x, 1.36.x — NÃO existe 1.33."
  default     = "v1.34.10"
}

variable "cluster_type" {
  type        = string
  description = "Tipo de cluster OKE: BASIC_CLUSTER (grátis) ou ENHANCED_CLUSTER (pago)."
  default     = "BASIC_CLUSTER"

  validation {
    condition     = contains(["BASIC_CLUSTER", "ENHANCED_CLUSTER"], var.cluster_type)
    error_message = "cluster_type deve ser BASIC_CLUSTER ou ENHANCED_CLUSTER."
  }
}

# ---------- Node Pool (Ampere A1 ARM64) ----------
# ⚠️ Cota Always Free do A1 foi CORTADA em 15/06/2026:
#    de 4 OCPU / 24 GB  ->  2 OCPU / 12 GB TOTAIS por tenancy
#    (1.500 OCPU-horas + 9.000 GB-horas/mês). Contas novas usam a cota nova.
# Default: 2 nodes x 1 OCPU / 6 GB = usa o teto inteiro com HA de nó
# (schedule dos pods de sistema distribui entre os 2; RAM por nó fica apertada
# nos labs mais pesados — ver Challenge para a alternativa 1 node x 2/12).
variable "node_shape" {
  type        = string
  description = "Shape ARM64. VM.Standard.A1.Flex é Always Free-eligible."
  default     = "VM.Standard.A1.Flex"
}

variable "node_count" {
  type        = number
  description = "Nº de worker nodes."
  default     = 2

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 2
    error_message = "node_count entre 1 e 2 (limite prático do A1 Always Free de 2 OCPU total)."
  }
}

variable "node_ocpus" {
  type        = number
  description = "OCPUs por node."
  default     = 1
}

variable "node_memory_gbs" {
  type        = number
  description = "Memória (GB) por node."
  default     = 6
}

variable "node_boot_volume_gbs" {
  type        = number
  description = "Boot volume por node (GB). Always Free: até 200 GB de Block Volume no total."
  default     = 50
}

# Guarda-corpo: garante que o node pool NÃO estoura a cota A1 (2 OCPU / 12 GB).
locals {
  total_ocpus  = var.node_count * var.node_ocpus
  total_memory = var.node_count * var.node_memory_gbs
}

resource "terraform_data" "free_tier_guard" {
  lifecycle {
    precondition {
      condition     = local.total_ocpus <= 2 && local.total_memory <= 12
      error_message = "Config estoura a cota Always Free do Ampere A1 (máx 2 OCPU / 12 GB total desde 15/06/2026). Atual: ${local.total_ocpus} OCPU / ${local.total_memory} GB."
    }
  }
}
