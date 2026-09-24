# =====================================================================
# LAB 01 — Exemplo de variáveis.
# Copie para terraform.tfvars (IGNORADO pelo git) e preencha com valores reais.
#   cp example.tfvars terraform.tfvars
# NUNCA commite terraform.tfvars nem a private key.
# =====================================================================

# --- Autenticação (Console > My profile > API Keys > Configuration File Preview) ---
tenancy_ocid     = "ocid1.tenancy.oc1..aaaa..."
user_ocid        = "ocid1.user.oc1..aaaa..."
fingerprint      = "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99"
private_key_path = "~/.oci/oci_api_key.pem"
region           = "sa-saopaulo-1"

# --- Compartment (vazio = usa o tenancy root; recomendado criar um dedicado) ---
compartment_ocid = ""

# --- Nomenclatura ---
project_name = "kubeforge"
environment  = "lab"

# --- Rede ---
vcn_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.0.0/24"
private_subnet_cidr = "10.0.1.0/24"
