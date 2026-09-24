# LAB 02 — Kubernetes com OKE

> ⚠️ **Opção B (alternativa).** Parte do caminho **Oracle Cloud**. Depende do [LAB 01/OCI](../lab-01/oci/README.md)
> e do estoque de **Ampere A1** em São Paulo, hoje bloqueado por `Out of host capacity`.
> **A trilha ativa é a [Opção A — AWS Academy + k3s ARM64](../lab-01/aws/README.md).**

> Segundo laboratório do [KubeForge](../README.md). Cria o primeiro cluster
> **Oracle Kubernetes Engine (OKE)** com worker nodes **Ampere A1 (ARM64)**,
> reutilizando a rede do [LAB 01](../lab-01/oci/README.md).

## 1. Objetivo

Subir um cluster Kubernetes gerenciado (OKE) com um node pool **ARM64** dentro da
cota **Always Free**, e acessá-lo com `kubectl`.

```text
Terraform → OCI → OKE → Ampere A1 (ARM64)
```

## 2. Pré-requisitos

**Ferramentas** (instalação por SO — macOS/Linux/Windows/WSL):
➡️ ver [Ferramentas e Pré-requisitos](../lab-01/oci/docs/prerequisites/README.md).
Você precisa de: **Terraform ≥ 1.5**, **OCI CLI**, **kubectl**, **jq**.

> ⚠️ **Ambiente testado: macOS.** Comandos podem variar em Linux/Windows. Em
> Windows, use **WSL2** para rodar os scripts `.sh` (não funcionam no PowerShell).

**Do LAB 01, você precisa ter em mãos:**

- **LAB 01 aplicado** — VCN, subnets e gateways existindo (`terraform apply` feito).
- Os **3 OCIDs de rede** (saída de `terraform output` em `lab-01/oci/terraform`):
  - `vcn_id` — OCID da VCN
  - `public_subnet_id` — subnet pública (endpoint do control plane + LBs)
  - `private_subnet_id` — subnet privada (worker nodes)
- A **mesma AUTH do LAB 01** (tenancy/user/fingerprint/private_key/region) — o
  `gen-tfvars.sh` copia isso automaticamente do `lab-01/oci/terraform/terraform.tfvars`.

> **Versão do Kubernetes:** as versões OKE mudam. Em 09/2026 existem
> **1.34.x, 1.35.x, 1.36.x** — **não existe 1.33**. Confira antes (seção 6).

## 3. Conceitos

- OKE (control plane gerenciado), Basic vs Enhanced cluster
- Node Pool, node shape flexível (A1.Flex), imagem OKE ARM64
- CNI (Flannel overlay padrão), pods/services CIDR
- `kubeconfig` e autenticação via OCI CLI (token 2.0.0)

## 4. Arquitetura

```text
                 Internet
                    │
             (endpoint público do API server)
                    ▼
        ┌───────────────────────────┐
        │  OKE control plane (grátis)│
        └─────────────┬─────────────┘
                      │  gerencia
                      ▼
        ┌───────────────────────────┐
        │  Node Pool ARM64 (A1.Flex) │  ← subnet PRIVADA (LAB 01)
        │  2 nodes × 1 OCPU / 6 GB   │
        └───────────────────────────┘
```

O control plane usa a **subnet pública** do LAB 01 para o endpoint e os LBs; os
**worker nodes** ficam na **subnet privada** (saem via NAT, sem IP público).

## 5. Implementação

1. Pegar os outputs do LAB 01.
2. Preencher o `terraform.tfvars` (auth + OCIDs de rede).
3. `terraform apply` → cluster + node pool.
4. Gerar o kubeconfig e validar com `kubectl get nodes`.

## 6. Terraform

**Opção rápida — script que puxa os OCIDs do LAB 01 automaticamente:**

```bash
cd lab-02/terraform
../scripts/gen-tfvars.sh          # cria terraform.tfvars, injeta vcn_id/subnets E a auth do LAB 01
terraform init
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

O `gen-tfvars.sh` lê `vcn_id`, `public_subnet_id` e `private_subnet_id` do state do
LAB 01 via `terraform output -raw`, **e também copia a AUTH** (tenancy/user/
fingerprint/private_key_path/region) do `lab-01/oci/terraform/terraform.tfvars` —
os dois labs usam a mesma API Key. Assim você não copia nada à mão. Se o
`lab-01/oci/terraform.tfvars` não existir (auth vinda só do `~/.oci/config`), o script
avisa e você preenche a auth do lab-02 manualmente.

**Opção manual:**

```bash
cd lab-02/terraform
cp example.tfvars terraform.tfvars   # preencha auth + vcn_id/subnets do LAB 01
terraform init
terraform validate
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**Windows nativo (sem WSL) / manual — sem o script:**

O `gen-tfvars.sh` é bash e **não roda no PowerShell**. Nesse caso, faça à mão:

1. Copie o exemplo: `copy example.tfvars terraform.tfvars` (PowerShell) /
   `cp example.tfvars terraform.tfvars` (bash).
2. Pegue os 3 OCIDs de rede do LAB 01:
   ```bash
   cd ../../lab-01/oci/terraform
   terraform output -raw vcn_id
   terraform output -raw public_subnet_id
   terraform output -raw private_subnet_id
   ```
3. Cole cada valor no `terraform.tfvars` do lab-02 (`vcn_id`, `public_subnet_id`,
   `private_subnet_id`).
4. Preencha a AUTH (`tenancy_ocid`, `user_ocid`, `fingerprint`, `private_key_path`,
   `region`) com os mesmos valores do LAB 01.

> **Descobrir a versão do Kubernetes suportada** (ajuste `kubernetes_version` no
> `terraform.tfvars` — em 09/2026 existem 1.34.x/1.35.x/1.36.x, **não** 1.33):
> ```bash
> oci ce cluster-options get --cluster-option-id all \
>   --query 'data."kubernetes-versions"' --output table
> ```

Depois do apply, gere o kubeconfig (o comando exato sai no output `kubeconfig_command`):

```bash
oci ce cluster create-kubeconfig \
  --cluster-id <cluster_id> \
  --file ~/.kube/config-kubeforge \
  --region sa-saopaulo-1 \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT

export KUBECONFIG=~/.kube/config-kubeforge
kubectl get nodes -o wide
```

## 7. Kubernetes

Resultado esperado:

```bash
$ kubectl get nodes -o wide
NAME          STATUS   ROLES   AGE   VERSION   ...   ARCH
10.0.1.x      Ready    node    2m    v1.33.1        arm64   ← ARM64!
```

A coluna **ARCH = arm64** é a prova de que o node é Ampere A1.

## 8. Segurança

- Cluster **BASIC_CLUSTER** (grátis). Endpoint público é o mais simples para o lab;
  em produção, avaliar endpoint privado + bastion.
- Worker nodes sem IP público (subnet privada do LAB 01).
- RBAC do Kubernetes entra em labs posteriores.

## 9. Testes

- `kubectl get nodes` retorna node(s) **Ready** com `ARCH=arm64`.
- `kubectl get pods -A` mostra os pods de sistema (CoreDNS, kube-proxy, flannel) rodando.
- Ver [`tests/`](tests/).

## 10. Troubleshooting

| Sintoma | Causa | Ação |
|---|---|---|
| `Out of host capacity` | Sem estoque de A1 em Sao Paulo | **NÃO é erro de config.** O cluster já subiu; só o node pool falhou. Rode o retry (abaixo) — `terraform apply` é idempotente e não recria o cluster |
| node fica `NotReady` | rota/NAT ausente | Conferir a route table privada do LAB 01 (NAT + SGW) |
| `kubectl` timeout | endpoint/token | Regerar kubeconfig; conferir `--kube-endpoint PUBLIC_ENDPOINT` |
| versão K8s inválida | `kubernetes_version` fora da lista | `oci ce cluster-options get` e ajustar |
| plan estoura o guard | sizing > 2 OCPU/12 GB | Ajustar `node_count`/`node_ocpus`/`node_memory_gbs` |

### 10.1 "Out of host capacity" — o mais comum

O control plane do OKE sobe fácil, mas o **node pool A1 falha** quando a Oracle
não tem estoque de Ampere na AD naquele momento. **Não é erro de config** — o
cluster já foi criado e está no state; só faltam os nodes. `terraform apply` é
idempotente: re-rodar **não recria o cluster**, só tenta o node pool de novo.

Retry automático com backoff (a partir de `lab-02/terraform`):

```bash
../scripts/retry-nodepool.sh          # 30 tentativas x 120s (~1h)
../scripts/retry-nodepool.sh 60 180   # ou: 60 tentativas x 180s (~3h)
```

O script re-tenta enquanto o erro for `Out of host capacity`; para na hora se
falhar por outro motivo. Windows: rode no **WSL2** (é bash) ou faça `terraform
apply` manualmente em loop.

Outras mitigações: tentar em horário de menor demanda; se sua região tiver mais
de uma AD, distribuir o node pool; em último caso, considerar outra região home
(mas a home é imutável — isso seria conta nova).

## 11. Challenge

Trocar o node pool para **1 node × 2 OCPU / 12 GB** (todo o teto num nó só) e
comparar: mais RAM contígua para componentes pesados (Prometheus, Cilium) versus
a resiliência de nó do default de 2 nós. Observar como os pods de sistema se
redistribuem.

> ⚠️ **Custo do Load Balancer (atenção para os labs 08/11):** o OCI dá **1
> Flexible Load Balancer + 10 Mbps grátis** (Always Free). Um `Service type:
> LoadBalancer` no OKE provisiona um LB real; se a banda mínima subir acima de
> 10 Mbps, **passa a cobrar**. Fixe o shape mínimo nas annotations do Service:
> ```yaml
> service.beta.kubernetes.io/oci-load-balancer-shape: "flexible"
> service.beta.kubernetes.io/oci-load-balancer-shape-flex-min: "10"
> service.beta.kubernetes.io/oci-load-balancer-shape-flex-max: "10"
> ```
> O **Network Load Balancer (L4)** é totalmente sem custo — alternativa quando
> não precisar de L7.

## 12. Resultado esperado

- Cluster OKE **ACTIVE**.
- Node pool ARM64 com node(s) **Ready** (`ARCH=arm64`).
- `kubeconfig` funcional apontando para o endpoint público.

## 13. Preparação para o próximo lab

Com o cluster no ar, o **LAB 03** roda o primeiro workload (Namespace, Deployment,
Service) — e valida que imagens **multi-arch / ARM64** rodam nos nodes Ampere.

---

**ARM64 Compatible:** YES (nodes Ampere A1) · **Free Tier:** sim (Basic cluster grátis; nodes dentro de 2 OCPU/12 GB) · **Custo:** zero
