# LAB 01 — AWS Academy + k3s multi-node (ARM64)

> ✅ Primeiro laboratório da trilha [KubeForge](../README.md).
> Sobe um cluster **k3s multi-node** (1 server + N agents) sobre EC2 **Graviton (ARM64)**
> no **AWS Academy Learner Lab**, provisionadas por **Terraform**.
>
> 📘 **Entender a fundo, custo, limites e troubleshooting:** [docs/referencia.md](docs/referencia.md).
> Este README é só o **passo a passo do que fazer**.

## 1. Objetivo

1. Ativar o **AWS Academy Learner Lab** e copiar as credenciais.
2. Provisionar por **Terraform**: VPC nova + N × EC2 Graviton + k3s.
3. Acessar o cluster com `kubectl`.
4. Terminar com `kubectl get nodes` mostrando **N nós Ready** com `ARCH=arm64`.

```text
AWS Academy Learner Lab → Terraform (VPC + EC2 t4g.large) → k3s (1 server + N agents) → kubectl
```

## 2. Papéis dos nós (k3s)

| Papel k3s | Equivalente Kubernetes | Função |
|---|---|---|
| **server** | control-plane + worker | API server, scheduler, banco (etcd embutido) — e também roda pods |
| **agent** | worker node | Só executa workloads (seus pods) |

Default: **1 server + 2 agents** (`agent_count = 2`) → 3 nós. Ajuste `agent_count` (`1` = 2 nós).
Detalhe do porquê em [docs/referencia.md](docs/referencia.md#papéis-dos-nós-k3s--detalhe).

## 3. Implementação (passo a passo)

**1. Ativar o Learner Lab e pegar as credenciais** → [docs/account-setup](docs/account-setup/README.md).
- **AWS Details → AWS CLI: Show** → cole o bloco `[default]` no seu `~/.aws/credentials`
  (renomeie o profile para `kubeforge`, ou ajuste `aws_profile` no tfvars).
- **AWS Details → Download PEM** → salve como `vockey.pem` (`chmod 400`).

**2. Configurar o DDNS Dynu — OBRIGATÓRIO, ANTES do tfvars** → [guia do Dynu](docs/dynu-ddns/README.md).
- Crie o hostname `kubeforge-<suas-iniciais>.ddnsgeek.com` no Dynu.
- Gere a **IP Update Password** (não a senha da conta).

> Por que obrigatório: o IP público muda a cada sessão de 4h; sem o hostname estável você
> refaria o kubeconfig toda vez, e o TLS do LAB 02 depende dele. O `terraform apply` **falha**
> (precondition) se `owner_initials`/`dynu_password` estiverem vazios.

**3. Preparar o Terraform** (com os valores do Dynu do passo 2 em mãos):
```bash
cd lab-01/terraform
cp example.tfvars terraform.tfvars
# edite terraform.tfvars:
#   my_ip_cidr     = "$(curl -s https://checkip.amazonaws.com)/32"
#   owner_initials = "mwl"                       # do passo 2
#   dynu_password  = "<sua IP Update Password>"  # do passo 2
terraform init
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**4. Pegar o kubeconfig.** O `apply` já imprime os comandos prontos — copie do output:
```bash
terraform output -raw kubeconfig_howto
```
Como o DDNS já foi configurado no passo 2, o `sed` usa o **hostname** (não o IP), então o
kubeconfig fica estável entre sessões — você reusa o mesmo quando o IP muda:
```bash
# o scp usa o IP/host do server (SSH); o endpoint do kubeconfig usa o HOSTNAME:
scp -i vockey.pem ubuntu@<server_public_ip>:~/.kube/config ~/.kube/config-kubeforge
sed -i '' 's#https://127.0.0.1:6443#https://kubeforge-<iniciais>.ddnsgeek.com:6443#' ~/.kube/config-kubeforge
export KUBECONFIG=~/.kube/config-kubeforge
kubectl get nodes -o wide   # N nós Ready, ARCH=arm64
```

## 4. Resultado esperado

N EC2 Graviton (ARM64), k3s ativo, `kubectl get nodes` → N nós **Ready** com `ARCH=arm64`.
Base pronta para o **LAB 02** (primeiro workload, agnóstico de provedor).

---

## 📘 Documentação (o "porquê" e o detalhe)

Movido do fluxo principal para não poluir o passo a passo. Leia se quiser entender a fundo
ou se algo deu errado — [docs/referencia.md](docs/referencia.md):

- **[Por que k3s em EC2 (não EKS/OKE)](docs/referencia.md#por-que-este-caminho)** — a decisão de arquitetura.
- **[Limites do Learner Lab](docs/referencia.md#limites-do-learner-lab)** — budget, sessão 4h, tipos EC2, IAM, verificação da SCP.
- **[Custo & budget (US$50)](docs/referencia.md#custo--budget-us50)** — quanto gasta por sessão.
- **[Como o cluster se monta (user_data)](docs/referencia.md#como-o-cluster-se-monta-user_data)** — server/agent, token, join por IP privado.
- **[DDNS — como funciona e troubleshooting](docs/referencia.md#dns-dinâmico-dynu--como-funciona-e-troubleshooting)** — `badauth`, `nohost`, cert x509.
- **[Reset de 4h](docs/referencia.md#reset-de-4-h-o-que-esperar)** — o que acontece e por que é transparente.
- **[Segurança](docs/referencia.md#segurança)** — SG por IP, segredos, trade-off do DDNS.

**Guias com prints:** [account-setup](docs/account-setup/README.md) · [Dynu DDNS](docs/dynu-ddns/README.md)

---

**ARM64 Compatible:** sim (Graviton t4g.large, SCP-confirmado) · **Free:** crédito US$50 do Learner Lab · **Custo real:** só a EC2 (<US$1/sessão)
