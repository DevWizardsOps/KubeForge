# LAB 01 — Terraform (OCI Foundation)

Provisiona a rede base do KubeForge na OCI (região **Brazil East / Sao Paulo**):
**VCN**, subnets **pública** e **privada**, **Internet Gateway**, **NAT Gateway**,
**Service Gateway**, **Route Tables** e **Security Lists**. Essa VCN é reutilizada
pelo **LAB 02 (OKE)**.

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `provider.tf` | Provider `oracle/oci ~> 9.0`, auth por API Key |
| `variables.tf` | Variáveis (auth, compartment, CIDRs) com validações |
| `locals.tf` | Nomenclatura, tags, compartment efetivo |
| `network.tf` | VCN + gateways + route tables + security lists + subnets |
| `outputs.tf` | OCIDs consumidos pelo LAB 02 |
| `example.tfvars` | Modelo — copie para `terraform.tfvars` (ignorado) |

## Pré-requisitos

1. Conta OCI Free Tier ativa — ver [`../docs/account-setup/`](../docs/account-setup/README.md).
2. **API Key gerada** — ver [`../docs/api-credentials/`](../docs/api-credentials/README.md) (private key em `~/.oci/oci_api_key.pem`, `chmod 600`).
3. Terraform >= 1.5.

## Como rodar

```bash
cd lab-01/terraform
cp example.tfvars terraform.tfvars   # preencha com seus OCIDs/fingerprint
terraform init
terraform fmt -check
terraform validate
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

> As credenciais vêm do `terraform.tfvars` **local** (ignorado pelo git) ou de
> `~/.oci/config`. **Nunca** versione `terraform.tfvars`, `*.tfstate` ou a private key.

## Cost Considerations

**ARM64 Compatible:** N/A (camada de rede) · **Free Tier:** sim · **Custo:** **zero**.

VCN, subnets, IGW, NAT Gateway, Service Gateway, route tables e security lists são
recursos **gratuitos** na OCI. O custo do Ampere A1 aparece no LAB 02.

## Destruir

```bash
terraform destroy -var-file=terraform.tfvars
```

## Troubleshooting

| Sintoma | Causa | Ação |
|---|---|---|
| `401-NotAuthenticated` | Fingerprint/private key errados | Conferir API Key no Console e o caminho da key |
| `404-NotAuthorizedOrNotFound` no compartment | OCID errado / sem permissão | Usar compartment válido; root = deixar `compartment_ocid=""` |
| `private_key_path` não encontrado | `~` não expandido | Usar caminho absoluto ou garantir expansão do shell |
| Limite de VCNs | Cota Free Tier | `terraform destroy` de labs antigos ou pedir aumento |
