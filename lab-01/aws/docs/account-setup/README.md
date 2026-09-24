# Ativar o AWS Academy Learner Lab

Guia de acesso ao ambiente da **Opção A**. O Learner Lab dá uma conta AWS temporária
(sem cartão) para lançar a EC2 onde o k3s vai rodar.

## 1. Acessar o lab

1. Entre no curso do **AWS Academy** (via Canvas/LMS da sua instituição).
2. Abra o módulo **Learner Lab** e clique em **Start Lab**.
3. Espere o indicador ao lado de **AWS** ficar **verde** (ambiente pronto).
4. Clique em **AWS** para abrir o **Management Console** já autenticado.

> ⏱️ **Sessão de 4 horas.** Um cronômetro conta no topo. Ao zerar (ou ao clicar **End Lab**),
> as instâncias EC2 **param** (stop) — não são deletadas. Você pode reiniciá-las na próxima sessão.

## 2. Credenciais para a CLI / Terraform (opcional)

Se for usar a **AWS CLI** local (para checar limites ou lançar a EC2 por linha de comando):

1. No painel do lab, clique em **AWS Details**.
2. Copie o bloco **AWS CLI** — ele traz `aws_access_key_id`, `aws_secret_access_key` e
   **`aws_session_token`** (as três são obrigatórias; são credenciais **temporárias**).
3. Cole em `~/.aws/credentials` sob um profile dedicado, ex.:
   ```ini
   [academy]
   aws_access_key_id = ASIA...
   aws_secret_access_key = ...
   aws_session_token = ...
   ```
4. Use com `--profile academy` e região `us-east-1`.

> 🔑 **Trocam a cada sessão.** Ao reabrir o lab, o `aws_session_token` muda — atualize o
> profile. **Nunca** commite essas credenciais.

## 3. A LabRole

O Learner Lab **não deixa você criar roles/policies IAM próprias**. Existe uma role
pré-criada chamada **`LabRole`** (e um instance profile equivalente) com um conjunto amplo
de permissões de serviço. Ao lançar a EC2, selecione esse perfil quando o console oferecer —
o k3s **não precisa** de permissão IAM nenhuma para rodar (ele é auto-contido na instância),
então a `LabRole` só serve para a EC2 existir.

## 4. Verificar os limites do SEU lab

Antes de escolher o tipo de instância, confirme o que a SCP da sua turma permite (a doc
oficial não garante Graviton):

```bash
# ARM (Graviton) existe na região?
aws --profile academy ec2 describe-instance-type-offerings --region us-east-1 \
  --filters Name=instance-type,Values=t4g.medium,t4g.small \
  --query 'InstanceTypeOfferings[].InstanceType' --output text

# Quota de vCPU On-Demand Standard:
aws --profile academy service-quotas get-service-quota \
  --service-code ec2 --quota-code L-1216C47A --region us-east-1
```

- Se `t4g.*` aparecer → tente ARM (o veredito final vem no `run-instances`).
- Se vier vazio ou o launch for negado por SCP → use `t3.medium` (x86); o bootstrap do k3s
  se adapta.

## 5. Troubleshooting

| Sintoma | Causa provável | Ação |
|---|---|---|
| Botão AWS não abre | Lab ainda inicializando | Espere o indicador verde |
| `UnauthorizedOperation` em `run-instances` | SCP bloqueia o tipo/ação | Troque de tipo (ARM→x86) ou tamanho (large→medium) |
| CLI dá `ExpiredToken` | `aws_session_token` venceu | Recopie o bloco AWS CLI em **AWS Details** |
| EC2 sumiu na volta | Instância foi reciclada (raro) | Relançar EC2 + rodar `bootstrap-k3s.sh` de novo |

---

Voltar ao [LAB 01 — AWS Academy + k3s](../../README.md).
