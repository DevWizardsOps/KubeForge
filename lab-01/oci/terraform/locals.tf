# =====================================================================
# LAB 01 — Locals: nomenclatura, tags e compartment efetivo
# =====================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Se compartment_ocid não for informado, cai no tenancy (root).
  compartment_id = var.compartment_ocid != "" ? var.compartment_ocid : var.tenancy_ocid

  common_tags = {
    project     = var.project_name
    environment = var.environment
    lab         = "lab-01-oci-foundation"
    managed_by  = "terraform"
  }
}
