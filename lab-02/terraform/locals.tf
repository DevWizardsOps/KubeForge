# =====================================================================
# LAB 02 — Locals e Data Sources
# =====================================================================

locals {
  name_prefix    = "${var.project_name}-${var.environment}"
  compartment_id = var.compartment_ocid != "" ? var.compartment_ocid : var.tenancy_ocid

  common_tags = {
    project     = var.project_name
    environment = var.environment
    lab         = "lab-02-oke"
    managed_by  = "terraform"
  }
}

# Availability Domains da região (Sao Paulo é single-AD: usamos [0]).
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Imagem mais recente compatível com OKE + ARM64 (Ampere) para a versão do K8s.
data "oci_containerengine_node_pool_option" "np_options" {
  node_pool_option_id = "all"
  compartment_id      = local.compartment_id
}
