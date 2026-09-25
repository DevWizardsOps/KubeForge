# Guia de ensino — LAB 01: AWS Academy + k3s ARM64

README do lab: `~/git/KubeForge/lab-01/aws/README.md`

## O problema que este lab resolve

"Quero um cluster Kubernetes ARM64 de verdade, sem pagar e sem cartão, pra
aprender." O OCI daria isso de graça (Ampere A1), mas está sem estoque. O AWS
Academy Learner Lab dá uma conta AWS temporária (US$50 de crédito, sem cartão) —
e em vez de EKS (que cobra o control plane), rodamos **k3s** dentro de uma EC2.

## Diagrama (mostre antes dos comandos)

```text
AWS Academy Learner Lab (conta temporária)
   │  terraform apply
   ▼
VPC própria ── subnet pública ── IGW        (SEM NAT/ELB: eles cobram entre sessões)
   │
   ├─ EC2 server  (t4g.large, ARM64)  ── k3s control-plane + roda pods
   ├─ EC2 agent-1 (t4g.large)         ── worker
   └─ EC2 agent-2 (t4g.large)         ── worker
        (agents fazem join no server pelo IP PRIVADO — estável entre resets)
```

## Conceitos-chave (explique nesta ordem)

1. **Learner Lab é efêmero mas persistente.** A sessão dura 4h; ao expirar, as
   EC2 **param** (não são deletadas). Na próxima sessão elas voltam — mas o **IP
   público muda** (por isso o LAB usa DDNS; ver lab-01 seção 7).
2. **k3s vs Kubernetes "completo".** k3s é Kubernetes conformante, empacotado num
   binário só, leve o bastante pra rodar num nó pequeno. O `server` é o
   control-plane; os `agents` são workers.
3. **server vs agent (ROLES).** No `kubectl get nodes`, o server mostra
   `control-plane` e os agents mostram `<none>`. `<none>` = worker comum, NÃO é
   erro (não existe label "worker" por padrão).
4. **IP privado vs público.** Os nós conversam por IP **privado** (`10.0.1.x`,
   coluna INTERNAL-IP) — estável e seguro. O IP público serve só pra SSH e pro
   kubectl de fora. Por isso EXTERNAL-IP aparece `<none>` (não foi registrado, e
   não precisa).
5. **SCP do Learner Lab.** A conta tem limites (SCP): só até `large`, ARM
   confirmado via `run-instances --dry-run`, sem criar roles IAM (só a LabRole),
   32 vCPUs, EBS <100GB, só us-east-1/us-west-2.

## Roteiro de ensino (passos)

1. Ativar o Learner Lab (Canvas → Start Lab → verde → console). Prints em
   `~/git/KubeForge/lab-01/aws/docs/account-setup/`.
2. Pegar credenciais (AWS Details → AWS CLI: Show) → `~/.aws/credentials`.
3. Confirmar a SCP com `run-instances --dry-run` (o `DryRunOperation` é o "pode").
4. `terraform.tfvars`: `my_ip_cidr`, `owner_initials`, `dynu_password`.
5. `terraform apply` → 12 recursos.
6. **Prova:** `kubectl get nodes -o wide` → 3 nós Ready, ARCH=arm64.

## Perguntas para checar entendimento

- "Se a sessão expira e as EC2 param, por que o cluster interno volta sozinho?"
  (join por IP privado, imutável; só o kubeconfig externo precisa do IP novo)
- "Por que não EKS?" (cobra control plane + IAM travado no Learner Lab)
- "Por que 1 OCPU do server = 2 vCPU no kubectl?" (contexto ARM: OCPU = core
  físico; aqui é t4g então já conta vCPU — cuidar pra não confundir com OCI)

## Erros comuns deste lab
Ver `gotchas.md`: `SEU.IP.PUBLICO.AQUI` no tfvars, credencial expirada,
`Out of host capacity` (OCI, não AWS).
