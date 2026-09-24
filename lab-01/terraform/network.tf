# =====================================================================
# LAB 01 — Rede: VCN + Gateways + Route Tables + Security Lists + Subnets
#
#                         Internet
#                            │
#                    ┌───────┴────────┐
#                    │ Internet GW    │  (só subnet pública)
#                    └───────┬────────┘
#            ┌───────────────┴───────────────┐
#            ▼                               ▼
#     ┌────────────┐                  ┌────────────┐
#     │  Public    │                  │  Private   │
#     │  Subnet    │                  │  Subnet    │──► NAT GW ──► Internet (saída)
#     │ 10.0.0/24  │                  │ 10.0.1/24  │──► Service GW ──► OCI Services
#     └────────────┘                  └────────────┘
# =====================================================================

# ---------- VCN ----------
resource "oci_core_vcn" "this" {
  compartment_id = local.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${local.name_prefix}-vcn"
  dns_label      = replace(var.project_name, "-", "")

  freeform_tags = local.common_tags
}

# ---------- Internet Gateway (subnet pública) ----------
resource "oci_core_internet_gateway" "igw" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-igw"
  enabled        = true

  freeform_tags = local.common_tags
}

# ---------- NAT Gateway (saída da subnet privada) ----------
resource "oci_core_nat_gateway" "nat" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-nat"

  freeform_tags = local.common_tags
}

# ---------- Service Gateway (acesso privado a serviços OCI, ex. Object Storage) ----------
data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_service_gateway" "sgw" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-sgw"

  services {
    service_id = data.oci_core_services.all_services.services[0]["id"]
  }

  freeform_tags = local.common_tags
}

# ---------- Route Table: pública (default route -> IGW) ----------
resource "oci_core_route_table" "public" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-rt-public"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }

  freeform_tags = local.common_tags
}

# ---------- Route Table: privada (default -> NAT ; serviços OCI -> SGW) ----------
resource "oci_core_route_table" "private" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-rt-private"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0]["cidr_block"]
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.sgw.id
  }

  freeform_tags = local.common_tags
}

# ---------- Security List: pública ----------
resource "oci_core_security_list" "public" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-sl-public"

  # Egress: tudo liberado
  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  # Ingress: SSH (22/tcp) — restrinja o source em produção
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ingress: ICMP tipo 3 código 4 (Path MTU) — recomendação OCI
  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }

  freeform_tags = local.common_tags
}

# ---------- Security List: privada ----------
resource "oci_core_security_list" "private" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.name_prefix}-sl-private"

  # Egress: tudo liberado (via NAT/SGW)
  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  # Ingress: apenas de dentro da VCN
  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr
  }

  # Ingress: ICMP Path MTU de dentro da VCN
  ingress_security_rules {
    protocol = "1"
    source   = var.vcn_cidr
    icmp_options {
      type = 3
      code = 4
    }
  }

  freeform_tags = local.common_tags
}

# ---------- Subnet pública (regional) ----------
resource "oci_core_subnet" "public" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${local.name_prefix}-subnet-public"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = local.common_tags
}

# ---------- Subnet privada (regional) — worker nodes OKE no LAB 02 ----------
resource "oci_core_subnet" "private" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "${local.name_prefix}-subnet-private"
  dns_label                  = "private"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = local.common_tags
}
