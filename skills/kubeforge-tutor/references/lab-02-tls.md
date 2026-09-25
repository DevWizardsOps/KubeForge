# Guia de ensino — LAB 02: Certificado TLS (cert-manager + Let's Encrypt)

README do lab: `~/git/KubeForge/lab-02/README.md`

## O problema que este lab resolve

"Meu app responde em HTTP, mas o browser mostra 'não seguro'. Quero HTTPS com um
certificado que o browser confie — de graça e renovado sozinho." É o que todo
serviço web precisa.

## Diagrama (mostre antes dos comandos)

```text
Internet ──▶ :443 ──▶ Traefik (Ingress, já vem no k3s) ──▶ app whoami
                          │
                          └─ cert-manager ──▶ Let's Encrypt (ACME HTTP-01)
                                                 │
                          valida em http://<host>/.well-known/acme-challenge/...
                                                 ▼
                                    emite cert + auto-renova (~30d antes)
```

## Conceitos-chave (explique nesta ordem)

1. **TLS = confiança + criptografia.** O cert prova "este servidor é mesmo
   `kubeforge-mwl.ddnsgeek.com`" e cifra o tráfego. Uma **CA** (Let's Encrypt)
   assina o cert; o browser confia na CA.
2. **ACME / HTTP-01.** O Let's Encrypt precisa provar que VOCÊ controla o
   domínio. No desafio HTTP-01 ele acessa `http://<host>/.well-known/...` — se
   responde, você controla. Por isso a **porta 80 tem que estar pública**
   (var `expose_web=true` abre 80/443 no SG).
3. **cert-manager.** É o operador Kubernetes que fala ACME por você: pede,
   guarda o cert num Secret, e renova sozinho. Você declara um `Certificate`
   (via anotação no Ingress) e ele cuida do resto.
4. **staging vs prod.** O Let's Encrypt **prod** tem limite (5 certs/semana por
   domínio) e emite cert CONFIÁVEL. O **staging** é ilimitado mas emite cert
   NÃO-confiável (cadeado vermelho). Regra: valide no staging, promova pro prod.
5. **Public Suffix List (por que ESTE domínio funciona).** `ddnsgeek.com` está na
   PSL (submetido pela Dynu), então o LE trata cada subdomínio como domínio
   próprio — seu limite de 5/semana é só seu.

## Roteiro de ensino (passos)

1. Pré: cluster do LAB 01 no ar, DDNS resolvendo (`dig`), `expose_web=true`.
2. Instalar cert-manager (`scripts/install-cert-manager.sh`).
3. ClusterIssuers staging+prod (trocar o e-mail).
4. App whoami + Ingress TLS apontando pro **staging**.
5. **Prova staging:** `kubectl get certificate` → READY=True; `curl -k https://...`.
6. Promover pro prod (troca o issuer, deleta o secret, reaplica).
7. **Prova prod:** `curl https://...` (sem `-k`) + `openssl ... -issuer` = Let's
   Encrypt (não STAGING) + cadeado verde no browser.

## Perguntas para checar entendimento

- "Por que a porta 80 precisa estar aberta pro MUNDO, e não só pro meu IP?"
  (o Let's Encrypt valida do lado dele, pela internet — HTTP-01)
- "Por que começar no staging?" (rate limit do prod: 5/semana)
- "O cert some quando a sessão de 4h expira?" (não — fica num Secret; o cluster
  volta. Só some se `terraform destroy`)
- "Quem renova o cert daqui a 60 dias?" (o cert-manager, sozinho)

## Aprendizado confirmado (25/09/2026)
O HTTP-01 **funciona** no Learner Lab (a borda deixa 80/443 pública passar).
Validado end-to-end: staging→prod, issuer Let's Encrypt, cadeado verde.

## Erros comuns deste lab
Ver `gotchas.md`: cert preso em False (`expose_web` não aplicado), acento na
description do SG, cadeado vermelho (é staging), rate limit.
