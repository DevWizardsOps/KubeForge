# LAB 01 — AWS Academy + k3s (ARM64)

> ✅ **Opção A (ativa).** Primeiro laboratório da trilha [KubeForge](../../README.md).
> Sobe um cluster **k3s single-node** sobre uma instância **EC2 do AWS Academy Learner Lab**,
> preferindo **Graviton (ARM64)**. Substitui a Opção B (OCI/OKE), bloqueada por falta de
> estoque de Ampere A1 em São Paulo.

## Por que este caminho

O caminho original (OCI/OKE, ARM64 Always Free) ficou bloqueado por `Out of host capacity`
do Ampere A1. Em vez de EKS (que cobra ~US$0,10/h pelo control plane e exige IAM que o
Learner Lab restringe), subimos **k3s dentro de uma EC2**:

- **Sem custo de control plane** — k3s roda na própria EC2; gasta só o crédito da instância.
- **Sem IAM do EKS** — a `LabRole` pré-criada do Learner Lab basta para lançar a EC2.
- **ARM64 preservado** — usamos Graviton (`t4g`) **se a SCP da turma permitir** (confirme na seção 3).

## 1. Objetivo

1. Ativar o **AWS Academy Learner Lab** e entender seus limites.
2. Lançar uma **EC2** (Graviton/ARM64 de preferência) na região `us-east-1`.
3. Instalar **k3s** e acessar o cluster com `kubectl`.
4. Terminar com `kubectl get nodes` mostrando um nó **Ready** com `ARCH=arm64`.

```text
AWS Academy Learner Lab → EC2 (t4g, ARM64) → k3s single-node → kubectl
```

## 2. Pré-requisitos

**Ferramentas locais** (no seu Mac/PC, para SSH e AWS CLI):
➡️ ver [Ferramentas e Pré-requisitos](../oci/docs/prerequisites/README.md) — você precisa de
**AWS CLI**, um cliente **SSH** e **kubectl** (o kubectl também pode rodar dentro da EC2).

**Conta:** acesso ao **AWS Academy Learner Lab** (via Canvas do curso). Não precisa de cartão.

➡️ **Comece por aqui:** [Ativar o Learner Lab e pegar as credenciais](docs/account-setup/README.md)

## 3. Limites do Learner Lab (confirme antes)

Os limites oficiais do Learner Lab (fonte: documento *AWS Academy Learner Lab – Foundational
Services*) que afetam este lab:

| Limite | Valor | Impacto aqui |
|---|---|---|
| **Budget** | US$100 (não renova) | k3s numa EC2 pequena gasta pouco; sobra folga |
| **Sessão** | 4 h; ao expirar **para** os sistemas | EC2 para (não deleta) → k3s volta ao reiniciar |
| **Regiões** | só `us-east-1` e `us-west-2` | use `us-east-1` |
| **vCPU total** | 32 vCPUs | de sobra para 1 EC2 |
| **Tipos EC2** | nano → medium garantidos; `large` nem sempre | `t3.medium`/`t4g.medium` (2 vCPU/4 GB) é o teto seguro |
| **EBS** | volume < 100 GB | disco de 20-30 GB basta |
| **IAM** | só a `LabRole` (sem criar roles) | k3s não precisa de IAM extra |

**Graviton (ARM64) é permitido?** O documento oficial lista **tamanhos** (nano→medium), mas
**não** especifica arquitetura — depende da SCP da sua turma. Confirme no lab ativo:

```bash
# Os tipos ARM existem na região? (offering)
aws ec2 describe-instance-type-offerings --region us-east-1 \
  --filters Name=instance-type,Values=t4g.medium,t4g.small \
  --query 'InstanceTypeOfferings[].InstanceType' --output text

# Quota real de vCPU On-Demand Standard:
aws service-quotas get-service-quota \
  --service-code ec2 --quota-code L-1216C47A --region us-east-1
```

O `describe-...offerings` diz se o tipo **existe na região**; o veredito final ("a SCP deixa
lançar") só vem ao tentar o `run-instances`. Se ARM for negado, use `t3.medium` (x86) — o
bootstrap se adapta sozinho.

## 4. Implementação

1. **Ativar o Learner Lab** e copiar as credenciais (`docs/account-setup/`).
2. **Lançar a EC2** (Graviton se possível):
   - AMI: **Amazon Linux 2023 arm64** ou **Ubuntu 24.04 arm64** (para `t4g`); a variante
     x86 da mesma AMI para `t3`.
   - Tipo: `t4g.medium` (ARM, 2 vCPU/4 GB) ou `t3.medium` (x86).
   - IAM: perfil `LabInstanceProfile`/`LabRole` (o que o lab oferecer).
   - Security Group: SSH (22) só do seu IP; k3s API (**6443**) só do seu IP se for acessar
     `kubectl` de fora — para uso via SSH na própria EC2, não precisa abrir 6443.
   - EBS: 20-30 GB gp3 (< 100 GB).
3. **Conectar por SSH** e rodar o bootstrap:
   ```bash
   # do seu Mac, copie o script para a EC2 (ou clone o repo lá):
   scp -i sua-chave.pem lab-01/aws/scripts/bootstrap-k3s.sh ec2-user@<IP>:~/
   ssh -i sua-chave.pem ec2-user@<IP>
   # dentro da EC2:
   chmod +x bootstrap-k3s.sh && ./bootstrap-k3s.sh
   ```

## 5. Bootstrap do k3s

O script [`scripts/bootstrap-k3s.sh`](scripts/bootstrap-k3s.sh):

- Detecta a **arquitetura** (arm64/amd64) e avisa se cair em x86.
- É **idempotente**: se o k3s já está ativo (pós-reset de 4h), reaproveita.
- Instala k3s single-node (`server`), copia o kubeconfig para `~/.kube/config`.
- Espera o nó ficar **Ready** e roda `kubectl get nodes -o wide`.

## 6. Reset de 4 h (o que esperar)

Ao fim da sessão do Learner Lab, a EC2 **para** (stop), não é deletada. Na próxima sessão:

1. Reabra o lab e **inicie** a EC2 (Start).
2. O IP público **muda** (a menos que você use Elastic IP — cuidado com o budget).
3. `ssh` no novo IP; o k3s volta sozinho com o estado. Se algo falhar, rode o bootstrap de
   novo (idempotente).

## 7. Segurança

- SSH e 6443 restritos ao **seu IP** no Security Group (nunca `0.0.0.0/0`).
- Não versione a chave `.pem` nem o kubeconfig (o `.gitignore` já cobre `*.pem`).
- Credenciais do Learner Lab (`aws_access_key_id`/`secret`/`session_token`) são **temporárias**
  e trocam a cada sessão — nunca commitar.

## 8. Resultado esperado

- EC2 ARM64 (ou x86 de fallback) rodando no Learner Lab.
- k3s ativo, `kubectl get nodes` → 1 nó **Ready**, coluna `ARCH` = `arm64`.
- Base pronta para os labs 03+ (agnósticos de provedor a partir daqui).

## 9. Preparação para o próximo lab

Com o cluster k3s de pé, o **LAB 03** (primeiro workload) roda igual em k3s ou OKE — os
manifests são padrão Kubernetes. A escolha de provedor (Opção A/B) só afeta os labs 01-02.

---

**ARM64 Compatible:** sim (Graviton) · **Free:** crédito US$100 do Learner Lab · **Custo real:** só a EC2 (baixo)
