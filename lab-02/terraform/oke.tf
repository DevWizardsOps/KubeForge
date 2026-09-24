# =====================================================================
# LAB 02 — OKE Cluster + Node Pool (Ampere A1 ARM64)
#
#   Control plane (OKE, grátis no BASIC_CLUSTER)
#        │  endpoint público  → subnet PÚBLICA (LAB 01)
#        ▼
#   Node Pool ARM64  → worker nodes na subnet PRIVADA (LAB 01)
#        │
#   Cota Always Free A1: 2 OCPU / 12 GB total (desde 15/06/2026)
# =====================================================================

# ---------- Cluster OKE ----------
resource "oci_containerengine_cluster" "this" {
  compartment_id     = local.compartment_id
  name               = "${local.name_prefix}-oke"
  vcn_id             = var.vcn_id
  kubernetes_version = var.kubernetes_version
  type               = var.cluster_type

  # Endpoint público do API server na subnet pública do LAB 01.
  endpoint_config {
    subnet_id            = var.public_subnet_id
    is_public_ip_enabled = true
  }

  options {
    service_lb_subnet_ids = [var.public_subnet_id]

    # CNI: FLANNEL_OVERLAY (padrão, grátis, ARM-ok). O LAB 09 avalia trocar por Cilium.
    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }
  }

  freeform_tags = local.common_tags
}

# ---------- Imagem do node (mais recente ARM64 p/ a versão do K8s) ----------
# Seleção da imagem do node: ARM64 (aarch64) + Oracle Linux 9 + versão OKE exata.
# Nome real das imagens: "Oracle-Linux-9.8-aarch64-2026.08.14-0-OKE-1.34.10-1820".
locals {
  k8s_clean = replace(var.kubernetes_version, "v", "") # ex: "1.34.10"

  arm_sources = [
    for s in data.oci_containerengine_node_pool_option.np_options.sources :
    s if can(regex("(?i)aarch64", s.source_name)) &&
    can(regex("Oracle-Linux-9", s.source_name)) &&
    can(regex("OKE-${replace(local.k8s_clean, ".", "\\.")}(-|$)", s.source_name))
  ]

  # última da lista filtrada (normalmente a mais recente)
  node_image_id = length(local.arm_sources) > 0 ? local.arm_sources[length(local.arm_sources) - 1].image_id : ""
}

# ---------- Node Pool ----------
resource "oci_containerengine_node_pool" "arm" {
  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = local.compartment_id
  name               = "${local.name_prefix}-np-arm64"
  kubernetes_version = var.kubernetes_version
  node_shape         = var.node_shape

  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_gbs
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.node_image_id
    boot_volume_size_in_gbs = var.node_boot_volume_gbs
  }

  # Todos os workers na subnet PRIVADA (single-AD em Sao Paulo).
  node_config_details {
    size = var.node_count

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = var.private_subnet_id
    }

    freeform_tags = local.common_tags
  }

  # Garante que o sizing cabe na cota antes de criar (ver terraform_data guard).
  depends_on = [terraform_data.free_tier_guard]

  lifecycle {
    precondition {
      condition     = local.node_image_id != ""
      error_message = "Nenhuma imagem OKE ARM64 (aarch64) Oracle-Linux-9 encontrada para a versão ${var.kubernetes_version}. Rode 'oci ce cluster-options get --cluster-option-id all --query 'data.\"kubernetes-versions\"'' e ajuste kubernetes_version (existem 1.34.x/1.35.x/1.36.x)."
    }
  }

  freeform_tags = local.common_tags
}
