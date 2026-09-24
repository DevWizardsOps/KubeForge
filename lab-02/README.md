# LAB 02 — Kubernetes com OKE

> Segundo laboratório do [KubeForge](../README.md). Cria o primeiro cluster
> **Oracle Kubernetes Engine (OKE)** com worker nodes **Ampere A1 (ARM64)**,
> reutilizando a rede do [LAB 01](../lab-01/README.md).

## 1. Objetivo

Subir um cluster Kubernetes gerenciado (OKE) com um node pool **ARM64** dentro da
cota **Always Free**, e acessá-lo com `kubectl`.

```text
Terraform → OCI → OKE → Ampere A1 (ARM64)
```

## 2. Pré-requisitos

- **LAB 01 aplicado** — a VCN, subnets e gateways precisam existir.
- Os **outputs do LAB 01** (`terraform output` em `lab-01/terraform`):
  `vcn_id`, `public_subnet_id`, `private_subnet_id`.
- API Key configurada (mesma do LAB 01) e **OCI CLI** instalado (para gerar o kubeconfig).
- `kubectl` instalado.

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
../scripts/gen-tfvars.sh          # cria terraform.tfvars e injeta vcn_id/subnets do LAB 01
# preencha a AUTH no terraform.tfvars (ou use ~/.oci/config)
terraform init
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

O `gen-tfvars.sh` lê `vcn_id`, `public_subnet_id` e `private_subnet_id` do state do
LAB 01 via `terraform output -raw` (não faz parse frágil de texto) e grava no
`terraform.tfvars` — assim você não copia OCID à mão. Ele **não** mexe na auth.

**Opção manual:**

```bash
cd lab-02/terraform
cp example.tfvars terraform.tfvars   # preencha auth + vcn_id/subnets do LAB 01
terraform init
terraform validate
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

> **Versão do Kubernetes:** confira as versões suportadas na região ANTES de aplicar:
> ```bash
> oci ce cluster-options get --cluster-option-id all \
>   --query 'data."kubernetes-versions"' --output table
> ```
> Ajuste `kubernetes_version` no `terraform.tfvars` se `v1.33.1` não estiver disponível.

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
| `Out of host capacity` | Sem A1 livre em Sao Paulo | Repetir o apply mais tarde; tentar outra AD; script de retry |
| node fica `NotReady` | rota/NAT ausente | Conferir a route table privada do LAB 01 (NAT + SGW) |
| `kubectl` timeout | endpoint/token | Regerar kubeconfig; conferir `--kube-endpoint PUBLIC_ENDPOINT` |
| versão K8s inválida | `kubernetes_version` fora da lista | `oci ce cluster-options get` e ajustar |
| plan estoura o guard | sizing > 2 OCPU/12 GB | Ajustar `node_count`/`node_ocpus`/`node_memory_gbs` |

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
