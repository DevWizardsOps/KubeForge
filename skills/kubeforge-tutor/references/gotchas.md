# Gotchas — erros reais da trilha KubeForge (e como diagnosticar)

Doc vivo: adicione cada erro novo que a turma bater, com **sintoma → causa →
cura**. É o material mais valioso pra ensinar (o erro é onde se aprende).

## LAB 01 — AWS Academy + k3s

| Sintoma | Causa | Cura |
|---|---|---|
| `"SEU.IP.PUBLICO.AQUI/32" is not a valid CIDR` | copiou o example.tfvars e não trocou `my_ip_cidr` | `my_ip_cidr = "$(curl -s https://checkip.amazonaws.com)/32"` |
| `ExpiredToken` no aws/terraform | credencial do Learner Lab (sessão 4h) venceu | recopiar bloco AWS Details → AWS CLI: Show |
| `Out of host capacity` | erro histórico da OCI (Ampere A1), não da AWS | foi o motivo do pivô para AWS; não ocorre na trilha atual |
| worker com ROLES `<none>` | padrão do Kubernetes (não há label 'worker') | NÃO é erro; opcional `kubectl label node <n> node-role.kubernetes.io/worker=worker` |
| EXTERNAL-IP `<none>` em todos os nós | nós não registrados com IP externo (usam privado) | correto e seguro; não mexer |
| IP do server mudou na volta da sessão | comportamento do Learner Lab | o DDNS repointa sozinho no boot; kubeconfig usa o hostname |

## LAB 02 — TLS / cert-manager

| Sintoma | Causa | Cura |
|---|---|---|
| `certificate` preso em READY=False por muito tempo | **`expose_web` não aplicado** (porta 80 fechada) — a causa nº1 | `terraform state show aws_security_group.k3s \| grep 'from_port = 80'`; se vazio, `expose_web=true` + `terraform apply` |
| `terraform plan` falha em `ingress.N.description doesn't comply` | acento/não-ASCII na `description` da regra de SG | só ASCII (sem `ú`, `—`) |
| Challenge: `connection refused`/timeout | porta 80 não chega no server | `expose_web=true` aplicado + `dig` batendo no IP; `curl -sI http://<host>` deve responder |
| cadeado vermelho / `CERT_AUTHORITY_INVALID` | você está no cert **staging** | promova pro prod (README lab-02 §7) |
| `No resources found` em `kubectl get challenges` | não há desafio pendente — em geral SUCESSO (challenge sumiu) | confirme com `kubectl get certificate` + `openssl ... -issuer` |
| rate limit do LE prod | emitiu 5x/semana | volte ao staging; espere a janela; não itere no prod |

## Técnica de diagnóstico (ensine isto)

1. **Sempre isole a camada.** Cert preso? Não chute — `kubectl describe
   certificate` → `describe challenge` → o erro está lá.
2. **Teste a porta de fora.** `curl -sS -m 8 -o /dev/null -w "HTTP %{http_code}\n"
   http://<host>/` prova se a 80 chega, independente do Kubernetes.
3. **State ≠ realidade.** `terraform state show` diz o que o TF acha; a AWS
   (`aws ec2 describe-security-groups`) é a fonte da verdade.
4. **Forçar retry** do ACME sem esperar backoff: `kubectl delete challenge --all;
   kubectl delete certificaterequest --all`.

## Gerais (KiroCrew / git)

| Sintoma | Causa | Cura |
|---|---|---|
| commit falha com `Inappropriate ioctl / gpg` | pinentry não abre no ambiente do agente | `git commit --no-gpg-sign` (não muda a config global) |
| push a `main` bloqueado pelo agente | policy: não push a branch protegido | o usuário faz `git push origin main` no próprio terminal |
