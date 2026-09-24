# =====================================================================
# LAB 02 — Outputs
# =====================================================================

output "cluster_id" {
  description = "OCID do cluster OKE."
  value       = oci_containerengine_cluster.this.id
}

output "cluster_name" {
  description = "Nome do cluster."
  value       = oci_containerengine_cluster.this.name
}

output "kubernetes_version" {
  description = "Versão do Kubernetes."
  value       = oci_containerengine_cluster.this.kubernetes_version
}

output "node_pool_id" {
  description = "OCID do node pool ARM64."
  value       = oci_containerengine_node_pool.arm.id
}

output "node_pool_sizing" {
  description = "Dimensionamento efetivo do node pool."
  value       = "${var.node_count} node(s) x ${var.node_ocpus} OCPU / ${var.node_memory_gbs} GB = ${local.total_ocpus} OCPU / ${local.total_memory} GB total"
}

# Comando para gerar o kubeconfig e acessar o cluster.
output "kubeconfig_command" {
  description = "Rode isto para configurar o kubectl (requer OCI CLI)."
  value       = <<-EOT
    oci ce cluster create-kubeconfig \
      --cluster-id ${oci_containerengine_cluster.this.id} \
      --file ~/.kube/config-kubeforge \
      --region ${var.region} \
      --token-version 2.0.0 \
      --kube-endpoint PUBLIC_ENDPOINT

    export KUBECONFIG=~/.kube/config-kubeforge
    kubectl get nodes -o wide
  EOT
}
