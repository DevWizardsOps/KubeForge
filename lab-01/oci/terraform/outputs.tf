# =====================================================================
# LAB 01 — Outputs (consumidos pelo LAB 02 / OKE)
# =====================================================================

output "vcn_id" {
  description = "OCID da VCN."
  value       = oci_core_vcn.this.id
}

output "vcn_cidr" {
  description = "CIDR da VCN."
  value       = var.vcn_cidr
}

output "public_subnet_id" {
  description = "OCID da subnet pública (LB / bastion)."
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "OCID da subnet privada (worker nodes OKE)."
  value       = oci_core_subnet.private.id
}

output "internet_gateway_id" {
  description = "OCID do Internet Gateway."
  value       = oci_core_internet_gateway.igw.id
}

output "nat_gateway_id" {
  description = "OCID do NAT Gateway."
  value       = oci_core_nat_gateway.nat.id
}

output "service_gateway_id" {
  description = "OCID do Service Gateway."
  value       = oci_core_service_gateway.sgw.id
}

output "compartment_id" {
  description = "Compartment efetivo usado."
  value       = local.compartment_id
}
