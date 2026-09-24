# =====================================================================
# LAB 01 — Variáveis
# =====================================================================

# ---------- Autenticação OCI (preencher no terraform.tfvars LOCAL) ----------
variable "tenancy_ocid" {
  description = "OCID do tenancy (Console > perfil > Tenancy)."
  type        = string
}

variable "user_ocid" {
  description = "OCID do usuário (Console > My profile)."
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint da API Key (Console > My profile > API Keys)."
  type        = string
}

variable "private_key_path" {
  description = "Caminho local da private key da API Key (ex: ~/.oci/oci_api_key.pem). NÃO versionar."
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "Região home. Brazil East (Sao Paulo)."
  type        = string
  default     = "sa-saopaulo-1"
}

# ---------- Compartment ----------
variable "compartment_ocid" {
  description = "OCID do compartment onde a rede será criada. Se vazio, usa o tenancy (root) — recomendado criar um compartment dedicado (ver Challenge)."
  type        = string
  default     = ""
}

# ---------- Nomenclatura ----------
variable "project_name" {
  description = "Prefixo de nomes dos recursos."
  type        = string
  default     = "kubeforge"
}

variable "environment" {
  description = "Ambiente lógico (dev/stg/prd) — usado em nomes e freeform_tags."
  type        = string
  default     = "lab"
}

# ---------- Rede (CIDRs) ----------
variable "vcn_cidr" {
  description = "CIDR da VCN."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "vcn_cidr precisa ser um CIDR IPv4 válido."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública (LB / bastion / node público futuro)."
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR da subnet privada (worker nodes OKE no LAB 02)."
  type        = string
  default     = "10.0.1.0/24"
}
