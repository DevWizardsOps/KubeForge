# LAB 02 — Certificado digital TLS (cert-manager + Let's Encrypt)

> Emite um **certificado TLS válido e auto-renovável** para um app exposto no
> cluster, usando **cert-manager** + **Let's Encrypt** (desafio ACME HTTP-01),
> pelo hostname DDNS do [LAB 01](../lab-01/README.md)
> (`kubeforge-<iniciais>.ddnsgeek.com`).
>
> Provedor-agnóstico: roda igual em k3s ou em qualquer Kubernetes gerenciado. Os comandos
> abaixo assumem o cluster do LAB 01 já no ar e `kubectl` configurado.

## 1. Objetivo

1. Instalar o **cert-manager** (operador de certificados do Kubernetes).
2. Configurar **ClusterIssuers** do Let's Encrypt (staging + prod).
3. Expor um app (**whoami**) via **Ingress** (Traefik, embutido no k3s).
4. Emitir o cert **staging**, validar o fluxo, e **promover para prod**.
5. Terminar com `https://kubeforge-<iniciais>.ddnsgeek.com` servindo cert confiável.

```text
Internet ─▶ :443 ─▶ Traefik (Ingress) ─▶ whoami
                        │
                        └─ cert-manager ─▶ Let's Encrypt (HTTP-01) ─▶ cert + auto-renovação
```

## 2. Pré-requisitos

- Cluster do LAB 01 no ar, `kubectl get nodes` mostrando os nós **Ready**.
- **DDNS ativo**: `dig +short kubeforge-<iniciais>.ddnsgeek.com` retorna o IP do server.
- **Porta 80/443 abertas ao público** — o desafio HTTP-01 do Let's Encrypt valida
  acessando `http://<hostname>/.well-known/acme-challenge/...` a partir da internet.
  No LAB 01, ligue no `terraform.tfvars`:
  ```hcl
  expose_web = true
  ```
  e rode `terraform apply`. Isso abre 80/443 para `0.0.0.0/0` (só o Ingress).

## 3. Por que este DNS funciona com Let's Encrypt

`ddnsgeek.com` está na **Public Suffix List** (submetido pela Dynu). Isso significa
que o Let's Encrypt trata `kubeforge-<iniciais>.ddnsgeek.com` como um **domínio
registrado próprio** — seu limite de 5 certs/semana é **só seu**, não compartilhado
com os outros usuários do `ddnsgeek.com`. Por isso a emissão funciona.

## 4. Instalar o cert-manager

```bash
cd lab-02
./scripts/install-cert-manager.sh
```
O script aplica os CRDs + controlador e espera os 3 pods (`cert-manager`,
`cert-manager-webhook`, `cert-manager-cainjector`) ficarem Ready.

## 5. Configurar os ClusterIssuers

1. Edite `manifests/01-clusterissuers.yaml` e **troque o e-mail** (`SEU_EMAIL@exemplo.com`)
   pelo seu — o Let's Encrypt manda avisos de expiração para ele.
2. Aplique:
   ```bash
   kubectl apply -f manifests/01-clusterissuers.yaml
   kubectl get clusterissuer     # ambos devem ficar READY=True
   ```

## 6. Subir o app + Ingress (STAGING primeiro)

1. Edite `manifests/03-whoami-ingress.yaml` e **troque `kubeforge-mwl.ddnsgeek.com`**
   pelo seu hostname (2 ocorrências: `tls.hosts` e `rules.host`). Deixe o issuer em
   `letsencrypt-staging`.
2. Aplique tudo:
   ```bash
   kubectl apply -f manifests/02-whoami-app.yaml
   kubectl apply -f manifests/03-whoami-ingress.yaml
   ```
3. Acompanhe a emissão do cert:
   ```bash
   kubectl get certificate            # whoami-tls: READY passa de False -> True
   kubectl describe certificate whoami-tls   # eventos do desafio ACME
   kubectl get challenges             # o HTTP-01 aparece e some quando valida
   ```
   Quando `whoami-tls` ficar **READY=True**, o staging emitiu com sucesso.

4. Teste (o cert staging **não é confiável** no browser — use `-k` no curl):
   ```bash
   curl -k https://kubeforge-<iniciais>.ddnsgeek.com
   # deve responder com os headers do whoami
   ```

## 7. Promover para PROD (cert confiável)

Só depois que o staging deu READY=True:

1. Edite `manifests/03-whoami-ingress.yaml`: troque a anotação para
   `cert-manager.io/cluster-issuer: letsencrypt-prod`.
2. Force a re-emissão:
   ```bash
   kubectl delete secret whoami-tls          # descarta o cert staging
   kubectl apply -f manifests/03-whoami-ingress.yaml
   kubectl get certificate -w                # aguarda READY=True (prod)
   ```
3. Teste **sem** `-k` (agora é confiável):
   ```bash
   curl https://kubeforge-<iniciais>.ddnsgeek.com     # sem erro de cert
   ```
   E abra no browser — cadeado verde. 🔒

## 8. Resultado esperado

- cert-manager rodando no cluster.
- `kubectl get certificate` → `whoami-tls` READY=True (emitido pelo prod).
- `https://kubeforge-<iniciais>.ddnsgeek.com` com cert Let's Encrypt válido.
- Renovação automática (cert-manager renova ~30 dias antes de expirar).

## 9. Troubleshooting

> ✅ **Validado end-to-end (25/09/2026) num Learner Lab real:** o HTTP-01 **funciona** —
> a borda do Learner Lab deixa 80/443 públicas passarem quando o security group as abre.
> Fluxo completo confirmado: staging → `READY=True`, promoção para **prod** → cert Let's
> Encrypt confiável (cadeado verde, `curl https://` sem `-k`). A emissão não é bloqueada
> pelo ambiente.

| Sintoma | Causa | Ação |
|---|---|---|
| `certificate` fica READY=False por muito tempo | **`expose_web` não foi aplicado** (porta 80 fechada) | Confirme no state: `terraform state show aws_security_group.k3s \| grep 'from_port = 80'`. Se não aparecer, `expose_web=true` + `terraform apply`. **Esta foi a causa real na 1ª execução.** |
| `terraform plan` falha em `ingress.N.description ... doesn't comply` | **acento/caractere não-ASCII** na description da regra de SG (a AWS só aceita ASCII básico) | Use só ASCII na `description` (sem `ú`, `—`, etc.). |
| Challenge: `connection refused` / timeout | porta 80 não chega no server | confirme `expose_web=true` + `terraform apply`; `dig` batendo no IP |
| `certificate` preso em `pending` | DNS não resolve pro server | `dig +short <hostname>` deve dar o IP do server (LAB 01 DDNS) |
| Rate limit do LE prod | emitiu 5x na semana | volte pro staging; espere a janela; nunca itere no prod |
| Browser: `NET::ERR_CERT_AUTHORITY_INVALID` | você está no cert **staging** | promova pro prod (seção 7) — staging é intencionalmente não-confiável |
| `no matches for kind Certificate` | cert-manager não instalado | rode `scripts/install-cert-manager.sh` |

> 💡 **Forçar retry sem esperar:** se você corrigiu a porta 80 com o cert já preso em False,
> `kubectl delete challenge --all; kubectl delete certificaterequest --all` faz o cert-manager
> retentar o HTTP-01 na hora (em vez de esperar o backoff).

## 10. Limpeza

```bash
kubectl delete -f manifests/03-whoami-ingress.yaml
kubectl delete -f manifests/02-whoami-app.yaml
# cert-manager pode ficar para os próximos labs; para remover:
# kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
```
Se quiser fechar 80/443 de novo: `expose_web = false` + `terraform apply` no LAB 01.

---

**ARM64:** cert-manager e whoami são multi-arch (rodam em Graviton) · **Custo:** zero (Let's Encrypt é grátis) · **Status:** ✅ validado end-to-end no Learner Lab — cert **PROD** emitido (issuer Let's Encrypt, cadeado verde no browser, HTTPS sem `-k`)
