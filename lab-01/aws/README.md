# LAB 01 — AWS Academy + k3s multi-node (ARM64)

> ✅ **Opção A (ativa).** Primeiro laboratório da trilha [KubeForge](../../README.md).
> Sobe um cluster **k3s multi-node** (1 server + N agents) sobre instâncias **EC2 Graviton
> (ARM64)** no **AWS Academy Learner Lab**, provisionadas por **Terraform**. Substitui a
> Opção B (OCI/OKE), bloqueada por falta de estoque de Ampere A1 em São Paulo.

## Por que este caminho

O caminho original (OCI/OKE, ARM64 Always Free) ficou bloqueado por `Out of host capacity`
do Ampere A1. Em vez de EKS (que cobra ~US$0,10/h pelo control plane e exige IAM que o
Learner Lab restringe), subimos **k3s dentro de EC2**:

- **Sem custo de control plane** — k3s roda nas próprias EC2; gasta só o crédito das instâncias.
- **Sem IAM do EKS** — a `LabRole` pré-criada do Learner Lab basta para lançar as EC2.
- **ARM64 preservado** — Graviton (`t4g.large`) **confirmado liberado pela SCP** (ver seção 3).

## 1. Objetivo

1. Ativar o **AWS Academy Learner Lab** e copiar as credenciais.
2. Provisionar por **Terraform**: VPC nova + N × EC2 Graviton + k3s.
3. Acessar o cluster com `kubectl`.
4. Terminar com `kubectl get nodes` mostrando **N nós Ready** com `ARCH=arm64`.

```text
AWS Academy Learner Lab → Terraform (VPC + EC2 t4g.large) → k3s (1 server + N agents) → kubectl
```

## 2. Papéis dos nós (k3s)

k3s tem dois papéis de nó:

| Papel k3s | Equivalente Kubernetes | Função |
|---|---|---|
| **server** | control-plane + worker | API server, scheduler, banco do cluster (etcd embutido) — e também roda pods |
| **agent** | worker node | Só executa workloads (seus pods) |

O default é **1 server + 2 agents** (`agent_count = 2`), dando um cluster multi-nó realista
para os labs de scheduling/affinity (labs 12+). Ajuste `agent_count` conforme a folga que quer:
`1` = 2 nós, `2` = 3 nós.

## 3. Limites do Learner Lab (confirmados neste ambiente)

| Limite | Valor | Como ficou aqui |
|---|---|---|
| **Budget** | **US$50** (não renova) | 3× t4g.large ligadas 4h ≈ **US$0,81/sessão** → 50+ sessões |
| **Sessão** | 4 h; ao expirar **para** as EC2 | EC2 param (não deletam) → k3s volta ao reiniciar |
| **Região** | só `us-east-1` e `us-west-2` | usamos `us-east-1` |
| **Tipos EC2** | ✅ **`t4g.large` (ARM64) liberado** | confirmado por `run-instances --dry-run` (SCP permite) |
| **EBS** | volume < 100 GB | disco de 30 GB gp3 |
| **IAM** | só a `LabRole` | k3s não precisa de IAM extra |
| **Elastic IP** | permitido | fixa o endpoint do server entre resets |

**Verificação da SCP (já feita nesta conta):**
```bash
# tipos existem na região?
aws ec2 describe-instance-type-offerings --region us-east-1 \
  --filters Name=instance-type,Values=t4g.large,m6g.large,t3.large --output text
# → t3.large  t4g.large  m6g.large  (todos existem)

# a SCP DEIXA lançar t4g.large? (dry-run não cria nada, não gasta)
aws ec2 run-instances --region us-east-1 --dry-run --count 1 \
  --instance-type t4g.large \
  --image-id resolve:ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id
# → "Request would have succeeded, but DryRun flag is set"  ✅ liberado
```

## 4. Custo & budget (US$50)

Sem NAT Gateway e sem ELB (os vilões que cobram entre sessões), o gasto é só a EC2:

| Setup | US$/h total | 4h ligadas | Se esquecer ligada 24h |
|---|---|---|---|
| 2 nós (1s+1a) t4g.large | ~US$0,134 | ~US$0,54 | ~US$3,2 |
| 3 nós (1s+2a) t4g.large | ~US$0,201 | ~US$0,81 | ~US$4,8 |

O Terraform cria **subnet pública + IGW, sem NAT** — zero cobrança entre sessões. No fim de
cada sessão, o Learner Lab **para** as EC2 automaticamente (não deleta). Só rode
`terraform destroy` quando quiser desmontar de vez.

## 5. Implementação (passo a passo)

1. **Ativar o Learner Lab** e pegar as credenciais → [account-setup](docs/account-setup/README.md).
   - **AWS Details → AWS CLI: Show** → cole o bloco `[default]` no seu `~/.aws/credentials`
     (renomeie o profile para `kubeforge`, ou ajuste `aws_profile` no tfvars).
   - **AWS Details → Download PEM** → salve como `vockey.pem` (chmod 400).
2. **Preparar o Terraform:**
   ```bash
   cd lab-01/aws/terraform
   cp example.tfvars terraform.tfvars
   # edite terraform.tfvars: my_ip_cidr = "$(curl -s https://checkip.amazonaws.com)/32"
   terraform init
   terraform plan  -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```
3. **Pegar o kubeconfig** (o `apply` imprime o passo a passo em `kubeconfig_howto`):
   ```bash
   scp -i vockey.pem ubuntu@<server_public_ip>:~/.kube/config ~/.kube/config-kubeforge
   sed -i '' 's#https://127.0.0.1:6443#https://<server_public_ip>:6443#' ~/.kube/config-kubeforge
   export KUBECONFIG=~/.kube/config-kubeforge
   kubectl get nodes -o wide   # N nós Ready, ARCH=arm64
   ```

## 6. Como o cluster se monta (user_data)

O Terraform injeta `user_data` em cada EC2:

- **server** ([`templates/server-userdata.sh.tftpl`](terraform/templates/server-userdata.sh.tftpl)):
  instala `k3s server` com um **token compartilhado** (gerado pelo Terraform) e `--tls-san`
  do IP público, para o cert do API server ser válido de fora.
- **agents** ([`templates/agent-userdata.sh.tftpl`](terraform/templates/agent-userdata.sh.tftpl)):
  esperam o server responder e fazem **join pelo IP PRIVADO** do server (estável dentro da
  VPC, sobrevive ao reset de 4h).

Ambos são **idempotentes**: pós-reset, se o k3s já está ativo, não reinstalam.

> O script [`scripts/bootstrap-k3s.sh`](scripts/bootstrap-k3s.sh) é a variante **manual/single-node**
> (rodar via SSH dentro de uma EC2) — mantido para quem quiser subir sem Terraform. O caminho
> recomendado é o Terraform acima.

## 7. Reset de 4 h (o que esperar)

Ao fim da sessão, as EC2 **param** (stop). Na próxima sessão:

1. Reabra o lab e **Start** — as EC2 reiniciam automaticamente.
2. O **Elastic IP do server é mantido** (endpoint estável); os agents reencontram o server
   pelo **IP privado** (imutável dentro da VPC). O cluster volta sozinho.
3. Se um agent não reconectar, `ssh` nele e confira `sudo systemctl status k3s-agent`.

## 8. Segurança

- SSH / 6443 / NodePort restritos ao **seu IP** (`my_ip_cidr`, `/32`) — nunca `0.0.0.0/0`.
- `vockey.pem`, `terraform.tfvars` e `*.tfstate` **não versionados** (`.gitignore` cobre).
- Credenciais do Learner Lab são **temporárias** (trocam a cada sessão) — nunca commitar.

## 9. Resultado esperado

- N EC2 Graviton (ARM64) no Learner Lab, VPC nova sem NAT.
- k3s ativo, `kubectl get nodes` → N nós **Ready**, `ARCH=arm64`.
- Base pronta para os labs 03+ (agnósticos de provedor a partir daqui).

## 10. Preparação para o próximo lab

Com o cluster k3s de pé, o **LAB 03** (primeiro workload) roda igual em k3s ou OKE — os
manifests são padrão Kubernetes. A escolha de provedor (Opção A/B) só afeta os labs 01-02.

---

**ARM64 Compatible:** sim (Graviton t4g.large, SCP-confirmado) · **Free:** crédito US$50 do Learner Lab · **Custo real:** só a EC2 (<US$1/sessão)
