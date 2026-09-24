# DNS real e gratuito com Dynu (opcional, mas recomendado)

> Parte do **LAB 01 — OCI Foundation** do [KubeForge](../../README.md).
> **Opcional.** Você só precisa disto quando os labs de Ingress/TLS chegarem
> (LAB 11 Gateway, LAB 12 cert-manager) — mas registre a conta **agora**, no
> começo da trilha, para não travar depois.

## Por que um DNS de verdade na trilha

O KubeForge vai expor serviços via **Ingress/Gateway** e emitir **certificados TLS
válidos** (cert-manager + Let's Encrypt). Para isso é preciso um **nome de domínio
real** apontando para o Load Balancer da OCI — não dá para emitir certificado
público para um IP nem para um hostname interno.

O [Dynu](https://www.dynu.com) resolve isso de graça:

- **Subdomínio grátis** (ex.: `kubeforge.freeddns.org`) ou hospedagem DNS do seu
  domínio próprio.
- **API v2** para criar/editar registros DNS por código — essencial para o
  desafio **DNS-01** do cert-manager (certificado **wildcard** `*.kubeforge...`)
  e para automação em geral.
- Registros **A/AAAA/CNAME/TXT**, TTL configurável.

> ⚠️ **Não é registrar de propósito** com a Oracle: o DNS fica no Dynu, fora da
> OCI, então **não gera custo** no seu Free Tier nem depende do cartão.

## 1. Criar a conta e o hostname

1. Acesse <https://www.dynu.com> → **Sign Up** (gratuito).
2. No painel → **DDNS Services** → **Add** → escolha um subdomínio gratuito
   (ex.: `kubeforge.freeddns.org`) ou adicione seu domínio próprio.
3. Crie o hostname. Ele já nasce com um registro A que você vai repontar para o
   IP do Load Balancer da OCI mais tarde.

## 2. Pegar a API Key

1. Painel → **Control Panel → API Credentials**
   (<https://www.dynu.com/en-US/ControlPanel/APICredentials>).
2. Em **API Key**, clique no ícone **View** e copie a chave.

> 🔒 A API Key é uma credencial: guarde fora do Git (ex.: variável de ambiente
> `DYNU_API_KEY`). O `.gitignore` do repo já bloqueia `.env`.

## 3. Testar a API

```bash
export DYNU_API_KEY="sua-chave"

# Listar seus domínios/hostnames (retorna id + name em JSON):
curl -s https://api.dynu.com/v2/dns -H "API-Key: $DYNU_API_KEY" | jq

# Atualizar o registro A de um hostname (DOMAINID vem do comando acima):
curl -s -X POST "https://api.dynu.com/v2/dns/{DOMAINID}" \
  -H "API-Key: $DYNU_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"kubeforge.freeddns.org","ipv4Address":"<IP-do-LoadBalancer-OCI>"}'
```

## Onde isto será usado na trilha

| Lab | Uso |
|---|---|
| LAB 11 (Gateway/Envoy) | Apontar o hostname para o IP do Load Balancer OCI (registro A) |
| LAB 12 (cert-manager) | Emitir TLS Let's Encrypt; **DNS-01 via API Dynu** para certificado **wildcard** |
| Qualquer lab com Ingress público | Nome estável em vez de IP |

O cert-manager tem webhook/solver de DNS-01 que fala com a API do Dynu — o
LAB 12 detalha a configuração (o `ClusterIssuer` usa a `DYNU_API_KEY` guardada
num Secret do Kubernetes).

## Cost Considerations

**Custo:** **zero** (Dynu free tier). Não usa recursos da OCI, não toca no cartão.

## ARM64 Compatibility

**ARM64 Compatible: N/A** — serviço DNS externo, independe da arquitetura.
