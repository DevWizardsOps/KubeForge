# Arquitetura da Rede — o que subimos e por quê

> Parte do **LAB 01 — OCI Foundation** do [KubeForge](../../README.md).
> Explica, recurso a recurso, a infraestrutura criada por
> [`../../terraform/`](../../terraform/README.md) e como ela sustenta todos os
> labs seguintes.

O `terraform plan` do LAB 01 cria **10 recursos**. Nenhum deles é pago — é a
fundação de rede sobre a qual o cluster **OKE / Ampere A1 (ARM64)** vai nascer no
LAB 02.

---

## Por que subir uma rede *antes* do Kubernetes?

No OKE, o cluster **não cria a própria rede**. Você entrega a ele uma **VCN** com
sub-redes já prontas: uma para o *control plane* / load balancers (pública) e uma
para os *worker nodes* (privada). Se a rede estiver errada (rota faltando, gateway
ausente, security list bloqueando), o cluster sobe mas os nodes não registram e os
pods não têm saída para a internet. Por isso a rede é o **LAB 01**: é a base que
todo o resto assume pronta.

---

## O diagrama

```text
                            INTERNET
                               │
                 ┌─────────────┼──────────────────────────┐
                 │             │                           │
        entra (SSH/LB)     sai (updates,                   │
                 │          pull de imagem)                │
                 ▼             ▲                           │
        ┌─────────────────┐    │                    ┌──────────────┐
        │ Internet Gateway│    │                    │  NAT Gateway │
        │      (IGW)      │    │                    │    (NAT)     │
        └────────┬────────┘    │                    └──────┬───────┘
                 │             │                           │
   ══════════════╪═════════════╪═══════════════════════════╪═══════ VCN 10.0.0.0/16
                 │             │                           │
                 ▼             │                           ▼
        ┌──────────────────┐   │                  ┌──────────────────┐
        │  Subnet PÚBLICA  │   │                  │  Subnet PRIVADA  │
        │   10.0.0.0/24    │   │                  │   10.0.1.0/24    │
        │                  │   │                  │                  │
        │ • LB / bastion   │   │                  │ • worker nodes   │
        │ • IP público OK  │   │                  │   OKE (LAB 02)   │
        │                  │   │                  │ • sem IP público │
        │ RT → IGW         │   │                  │ RT → NAT + SGW   │
        │ SL: 22/tcp, ICMP │   │                  │ SL: só da VCN    │
        └──────────────────┘   │                  └────────┬─────────┘
                               │                           │
                               │                           ▼
                               │                  ┌──────────────────┐
                               └──────────────────│ Service Gateway  │
                                  acesso PRIVADO   │      (SGW)       │
                                  a serviços OCI   │ Object Storage,  │
                                  (sem passar      │ Registry, etc.   │
                                   pela internet)  └──────────────────┘
```

---

## Recurso a recurso (os 10 do plan)

| # | Recurso Terraform | O que é | Por que existe |
|---|---|---|---|
| 1 | `oci_core_vcn.this` | **VCN** `10.0.0.0/16` | A rede virtual isolada. Tudo vive dentro dela. `/16` dá ~65k IPs — espaço de sobra para subnets de todos os labs. |
| 2 | `oci_core_internet_gateway.igw` | **Internet Gateway** | Porta de entrada/saída **pública**. Só a subnet pública o usa (LB, bastion, acesso externo). |
| 3 | `oci_core_nat_gateway.nat` | **NAT Gateway** | Deixa a subnet **privada** *sair* para a internet (baixar updates, `docker pull`) **sem** aceitar conexões de entrada. É o que mantém os worker nodes sem IP público mas ainda funcionais. |
| 4 | `oci_core_service_gateway.sgw` | **Service Gateway** | Caminho **privado** para serviços da própria OCI (Object Storage, Container Registry). O tráfego não sai para a internet — mais rápido, mais seguro, e não gasta banda do NAT. Útil já no LAB 17 (Harbor) e LAB 25 (Velero → Object Storage). |
| 5 | `oci_core_route_table.public` | **Route Table pública** | Regra `0.0.0.0/0 → IGW`: quem está na subnet pública alcança a internet direto. |
| 6 | `oci_core_route_table.private` | **Route Table privada** | Duas regras: `0.0.0.0/0 → NAT` (saída) e `serviços OCI → SGW` (acesso privado). É o que separa "sair pra internet" de "falar com a OCI". |
| 7 | `oci_core_security_list.public` | **Security List pública** | Firewall da subnet pública: entra **SSH (22/tcp)** e **ICMP Path-MTU**; sai tudo. *(Endurecer o source do SSH é o Challenge do lab.)* |
| 8 | `oci_core_security_list.private` | **Security List privada** | Firewall da subnet privada: só aceita tráfego **de dentro da VCN** (`10.0.0.0/16`). Worker nodes não recebem nada da internet diretamente. |
| 9 | `oci_core_subnet.public` | **Subnet pública** `10.0.0.0/24` | Onde ficam Load Balancers e um eventual bastion. `prohibit_public_ip_on_vnic = false` (pode ter IP público). |
| 10 | `oci_core_subnet.private` | **Subnet privada** `10.0.1.0/24` | Onde os **worker nodes do OKE** vão rodar (LAB 02). `prohibit_public_ip_on_vnic = true` (nunca IP público). |

> O `data.oci_core_services` que aparece no plan **não é um recurso** — é uma
> *consulta* que descobre o CIDR dos serviços OCI da região (em Sao Paulo aparece
> como `all-gru-services-in-oracle-services-network`) para alimentar a rota do SGW.

---

## Por que essa topologia (pública + privada)

É o padrão de **defesa em profundidade** para Kubernetes gerenciado:

- **Worker nodes na subnet privada** = não têm IP público, não são alcançáveis da
  internet. Reduz drasticamente a superfície de ataque.
- **Saída via NAT** = os nodes ainda baixam imagens e updates, mas ninguém entra.
- **Entrada só pela subnet pública** via Load Balancer (LAB 08/11) — o tráfego do
  usuário chega no LB público e é encaminhado para os pods na rede privada.
- **Service Gateway** = tráfego para a própria OCI nem passa pela internet.

Essa separação é a mesma que se usa em produção — o lab ensina o padrão certo
desde o começo, não uma versão "tudo público" que precisaria ser refeita depois.

---

## Como essa infra evolui pelos labs

A rede do LAB 01 **não é recriada** a cada lab — ela é a base, e cada lab
adiciona uma camada por cima:

```text
LAB 01  ── VCN + Subnets + Gateways + Security Lists      (esta camada)
   │
LAB 02  ── OKE (control plane) + Node Pool Ampere A1 ARM64  → na subnet privada
   │
LAB 03  ── Workloads (Deployments, Services)               → dentro do cluster
   │
LAB 08+ ── LoadBalancer / Ingress                          → usa a subnet pública
   │
LAB 09  ── Cilium (eBPF) substitui/complementa o CNI
   │
LAB 17  ── Harbor (registry)                               → SGW p/ Object Storage
   │
LAB 25  ── Velero (backup)                                 → SGW p/ Object Storage
```

- **Terraform** cuida da camada de **infraestrutura** (VCN, OKE, compute).
- **GitOps (Argo CD, a partir do LAB 06)** cuida da camada de **plataforma**
  (apps, operadores, políticas) *dentro* do cluster.

---

## Divisão de responsabilidade (Terraform × GitOps)

```text
        Terraform                         GitOps (Argo CD)
            │                                   │
            ▼                                   ▼
   ┌──────────────────┐               ┌──────────────────────┐
   │  OCI / Infra     │               │  Kubernetes / Plataforma │
   │  • VCN (LAB 01)  │               │  • Apps               │
   │  • OKE (LAB 02)  │               │  • Operadores         │
   │  • Compute A1    │               │  • Políticas          │
   └──────────────────┘               │  • Secrets            │
                                      └──────────────────────┘
```

A regra: **se é recurso da nuvem, é Terraform; se roda dentro do Kubernetes, é
GitOps.**

---

## Cost Considerations

**ARM64 Compatible:** N/A (rede) · **Free Tier:** sim · **Custo:** **zero**.

VCN, subnets, gateways, route tables e security lists são **gratuitos** na OCI.
O primeiro custo (dentro do Free Tier) aparece no LAB 02 com o Ampere A1
(cota grátis: **4 OCPUs + 24 GB RAM** distribuídos entre até 4 VMs).

## Como destruir

```bash
cd lab-01/terraform
terraform destroy -var-file=terraform.tfvars
```

Como nada aqui é pago, você pode deixar a rede de pé entre os labs — ela é
reaproveitada. Só destrua se quiser zerar o ambiente.
