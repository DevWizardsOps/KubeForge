# =====================================================================
# LAB 02 — Exemplo de variáveis.
# Copie para terraform.tfvars (IGNORADO pelo git) e preencha.
#   cp example.tfvars terraform.tfvars
# =====================================================================

# --- Autenticação (mesma API Key do LAB 01) ---
tenancy_ocid     = "ocid1.tenancy.oc1..aaaa..."
user_ocid        = "ocid1.user.oc1..aaaa..."
fingerprint      = "aa:bb:cc:...:99"
private_key_path = "~/.oci/oci_api_key.pem"
region           = "sa-saopaulo-1"
compartment_ocid = ""

# --- Rede: OUTPUTS do LAB 01 (rode `terraform output` em lab-01/terraform) ---
vcn_id            = "ocid1.vcn.oc1.sa-saopaulo-1..."
public_subnet_id  = "ocid1.subnet.oc1.sa-saopaulo-1...(publica)"
private_subnet_id = "ocid1.subnet.oc1.sa-saopaulo-1...(privada)"

# --- Kubernetes ---
kubernetes_version = "v1.34.10" # confira as versões suportadas na região antes (ver README). NÃO existe 1.33.
cluster_type       = "BASIC_CLUSTER"

# --- Node Pool Ampere A1 (cota Always Free: 2 OCPU / 12 GB total desde 15/06/2026) ---
node_shape           = "VM.Standard.A1.Flex"
node_count           = 2
node_ocpus           = 1
node_memory_gbs      = 6
node_boot_volume_gbs = 50
