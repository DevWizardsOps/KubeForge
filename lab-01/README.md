# LAB 01 — OCI Foundation

> Primeiro laboratório da trilha [KubeForge](../README.md). Objetivo: conhecer a Oracle Cloud,
> criar a conta Free Tier e preparar a infraestrutura de rede base (VCN) sobre a qual o cluster
> **OKE / Ampere A1 (ARM64)** será construído no LAB 02.

## 1. Objetivo

Preparar a fundação na **Oracle Cloud Infrastructure (OCI)**:

1. Criar uma conta **Free Tier** pessoal com região home **Brazil East (Sao Paulo)**.
2. Compreender os conceitos base de OCI (Compartments, IAM, Regions, ADs).
3. Provisionar uma rede funcional (VCN, Subnets, Gateways, Route Tables, Security Lists/NSG).
4. Ter o primeiro contato com **Terraform** usando o **OCI Provider**.

## 2. Pré-requisitos

- E-mail e telefone válidos.
- **Cartão de crédito/débito real** (verificação de identidade — sem cobrança no Free Tier).
- Ainda **não ter** conta Oracle Cloud (limite de 1 por pessoa).

➡️ **Comece por aqui:** [Criação da Conta Oracle Cloud Free Tier](docs/account-setup/README.md)

➡️ **Para o Terraform:** [Gerar a Credencial de API (API Key)](docs/api-credentials/README.md)

## 3. Conceitos

- OCI, Compartments, IAM (usuários, grupos, políticas)
- Regions e Availability Domains
- VCN, Subnets, Internet Gateway, NAT Gateway, Route Tables
- Security Lists e Network Security Groups (NSG)

## 4. Arquitetura

📐 **Explicação detalhada, recurso a recurso, com diagrama:** [Arquitetura da Rede — o que subimos e por quê](docs/architecture/README.md)

```text
Oracle Cloud (Region: Brazil East - Sao Paulo)
        │
        ▼
      VCN
        │
   ┌────┴─────┐
   ▼          ▼
 Public     Private
 Subnet     Subnet
   │          │
Internet    NAT
Gateway    Gateway
```

## 5. Implementação

1. Criar a conta (ver `docs/account-setup/`).
2. Explorar o Console: Compartments e IAM.
3. Provisionar a VCN e sub-redes via Terraform (`terraform/`).

## 6. Terraform

```text
Terraform → OCI Provider → OCI Infrastructure (VCN, Subnets, Gateways)
```

> O código Terraform desta camada ficará em [`terraform/`](terraform/). Credenciais **não** vão para
> o Git — usar variáveis/`OCI_*` env ou arquivo de config fora do versionamento.

## 7. Kubernetes

Não aplicável neste lab. O cluster OKE entra no **LAB 02**.

## 8. Segurança

- IAM: princípio do menor privilégio (grupos + policies por compartment).
- Não armazenar credenciais no repositório.
- Security Lists/NSG restritivos por padrão.

## 9. Testes

- Validar acesso ao Console.
- `terraform plan`/`apply` idempotentes.
- Conectividade da rede (rotas e gateways).

## 10. Troubleshooting

Ver a seção de troubleshooting do guia de conta em
[`docs/account-setup/README.md`](docs/account-setup/README.md#troubleshooting).

## 11. Challenge

Criar um **compartment dedicado** ao KubeForge e uma **policy IAM** que conceda a um grupo apenas o
necessário para gerenciar rede — tudo via Terraform.

## 12. Resultado esperado

- Conta Free Tier ativa (região Sao Paulo).
- `terraform plan` → **10 recursos a criar** (VCN, IGW, NAT GW, Service GW, 2 route tables, 2 security lists, 2 subnets).
- VCN funcional com sub-redes pública e privada.
- Estado Terraform versionável (sem segredos).

## 13. Preparação para o próximo lab

Com a rede pronta, o **LAB 02 — Kubernetes com OKE** provisiona o primeiro cluster com node pool
**Ampere A1 (ARM64)** nesta mesma VCN.

---

**ARM64 Compatible:** N/A (fundação de conta/rede) · **Free Tier:** sim · **Custo:** zero
