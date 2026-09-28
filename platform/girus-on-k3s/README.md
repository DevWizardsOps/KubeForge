# GIRUS on k3s — plataforma de aprendizado de Kubernetes

Sobe a **plataforma GIRUS** (LINUXtips) no **nosso** cluster k3s ARM64 (LAB 01),
em vez do Kind local que o CLI oficial cria. É a base da **Fase 1** da trilha
(aprender os primitivos do Kubernetes de forma interativa, com terminal no
browser e validação automática). Ver [`docs/ROADMAP.md`](../../docs/ROADMAP.md).

> **Não é um lab da trilha** — é a *plataforma* onde os labs de fundamentos de
> k8s rodam. Os labs numerados (`lab-01`, `lab-02`, `lab-03`...) são a **Fase 2**
> (entrega de software: Helm, GitOps, etc.).

## Pré-requisitos

| # | Vem de | O quê |
|---|---|---|
| 1 | LAB 01 | Cluster k3s no ar + `KUBECONFIG` apontando pra ele + registro **wildcard** `*.kubeforge-<iniciais>.ddnsgeek.com` no Dynu (A → IP do server) |
| 2 | LAB 02 | `cert-manager` instalado + ClusterIssuer `letsencrypt-prod` **Ready** |

### Hostname via wildcard (sem registrar DNS novo)

O DDNS (Dynu) do LAB 01 já tem um registro **curinga** `*.kubeforge-<iniciais>.ddnsgeek.com`
apontando para o IP do server. Então **qualquer subdomínio já resolve pro cluster** — o Girus
usa `girus.kubeforge-<iniciais>.ddnsgeek.com` sem precisar de nenhum registro novo. O Traefik
roteia pelo header `Host:`, e o Let's Encrypt valida (HTTP-01) porque o wildcard resolve.

> **Padrão da trilha:** cada serviço futuro ganha `<nome>.kubeforge-<iniciais>.ddnsgeek.com`
> de graça pelo wildcard. Confirme que resolve: `dig +short girus.kubeforge-<iniciais>.ddnsgeek.com`
> deve devolver o IP do server. (O wildcard cobre **um** nível de subdomínio.)

## Como subir

```bash
export KUBECONFIG=~/.kube/config-kubeforge

# 1. Troque o hostname nos dois arquivos (girus-mwl -> girus-<suas-iniciais>):
#    - 02-girus-ingress.yaml  (spec.tls[].hosts e spec.rules[].host)
sed -i '' 's/girus-mwl/girus-<suas-iniciais>/g' 02-girus-ingress.yaml   # macOS

# 2. Plataforma (namespace, RBAC, backend, frontend, services, nginx):
kubectl apply -f 01-girus-platform.yaml

# 3. Ingress + TLS (cert-manager emite o cert do host girus-<iniciais>):
kubectl apply -f 02-girus-ingress.yaml

# 4. Aguarde o cert ficar Ready (pode levar ~1-2 min no HTTP-01):
kubectl -n girus get certificate girus-frontend-tls -w
```

Acesse: `https://girus-<iniciais>.ddnsgeek.com` — a interface do Girus com o
terminal interativo.

## Carregar os labs de fundamentos

Os labs do Girus são **ConfigMaps** (`kind: ConfigMap` com o `lab.yaml` dentro).
A trilha de fundamentos de k8s do Girus inclui: Fundamentos, Deployment,
Exploração de Recursos, Serviços e Redes, ConfigMaps e Secrets, CronJobs.

Duas formas de carregá-los:

- **Via CLI do Girus** (na sua máquina, aponta para o cluster): `girus lab list` /
  `girus lab start <lab>` — porém a CLI assume o Kind dela; use só se souber
  apontar o kubeconfig para o k3s.
- **Direto via kubectl** (recomendado aqui): aplique o ConfigMap do lab no
  namespace `girus` e o backend o detecta. Os `lab.yaml` de fundamentos estão no
  repo do Girus (`internal/templates/manifests/lab_4*_kubernetes_*.yaml`).

> Curadoria pendente: vamos selecionar QUAIS labs de fundamentos entram na Fase 1
> (e em que ordem) — ver ROADMAP. Nem todo lab do Girus é de Kubernetes.

## Segurança / RBAC — leia antes de usar

O manifesto **original** do Girus concede **`cluster-admin` GLOBAL** a uma
ServiceAccount de lab (`lab-test-user`). Num Kind descartável, tudo bem. **Neste
cluster que persiste entre sessões, é risco desnecessário** — então **removemos**
esse binding. O backend do Girus continua criando os namespaces/pods de cada lab
sob demanda pela `girus-cluster-role`, com verbos específicos (sem admin global).

Se um lab específico exigir mais permissão, conceda o **mínimo adicional a ele**,
nunca `cluster-admin` global. O cluster é efêmero (Learner Lab hiberna em 4h),
mas ainda assim: menor privilégio por padrão.

## Validar

```bash
export KUBECONFIG=~/.kube/config-kubeforge
./tests/verify.sh   # backend/frontend Running, Ingress+cert Ready, HTTPS 200 sem -k
```

## Derrubar

```bash
kubectl delete -f 02-girus-ingress.yaml
kubectl delete -f 01-girus-platform.yaml
# (o namespace girus é removido junto; os labs criados por ele também)
```

## Créditos e licença

Este módulo **adapta** a plataforma **GIRUS**, um projeto **open-source da
[LINUXtips](https://linuxtips.io)** (autor: [badtuxx](https://github.com/badtuxx)):

- **Projeto original:** [github.com/badtuxx/girus-cli](https://github.com/badtuxx/girus-cli)
- **Licença:** **GPL-3.0** — este material derivado herda a GPL-3.0. Veja a
  licença original no repositório do GIRUS.
- **Imagens:** `linuxtips/girus-backend:0.5.0` e `linuxtips/girus-frontend:0.5.0`
  (Docker Hub, publicadas pela LINUXtips) — **multi-arch**, com build `arm64`
  confirmado (rodam no Graviton).

**Modificações nossas** em relação ao `defaultDeployment.yaml` original (declaradas
como exige a GPL): imagens **pinadas** em `:0.5.0` (o original usa `:latest`);
acesso externo por **Ingress + TLS** reusando o Traefik/cert-manager do LAB 02 (o
original usa `port-forward` do Kind); **RBAC reduzido** (removido o
`ClusterRoleBinding` para `cluster-admin` global da SA de lab).

> Todo o crédito pela plataforma GIRUS é da LINUXtips e seus contribuidores. Este
> módulo apenas a hospeda no nosso cluster para fins de estudo — não implica
> endosso da LINUXtips ao KubeForge. Para a experiência oficial, use o
> [girus-cli](https://github.com/badtuxx/girus-cli).
