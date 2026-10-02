# GIRUS on k3s — plataforma de aprendizado de Kubernetes

Sobe a **plataforma GIRUS** (LINUXtips) no **nosso** cluster k3s ARM64 (LAB 01),
em vez do Kind local que o CLI oficial cria. É a base da **Fase 1** da trilha
(aprender os primitivos do Kubernetes de forma interativa, com terminal no
browser e validação automática). Ver [`docs/ROADMAP.md`](../../docs/ROADMAP.md).

> **Não é um lab da trilha** — é a *plataforma* onde os labs de Kubernetes rodam
> (fundamentos **e** entrega de software: Helm, e futuramente GitOps etc.). Os
> labs numerados que sobraram (`lab-01`, `lab-02`) são só a **infra de plataforma**
> que sobe o cluster e o HTTPS onde o Girus roda.

## Pré-requisitos

| # | Vem de | O quê |
|---|---|---|
| 1 | LAB 01 | Cluster k3s no ar + `KUBECONFIG` apontando pra ele + registro **wildcard** `*.$KUBEFORGE_HOST` no Dynu (A → IP do server) |
| 2 | LAB 02 | `cert-manager` instalado + ClusterIssuer `letsencrypt-prod` **Ready** |

### Hostname via wildcard (sem registrar DNS novo)

O DDNS (Dynu) do LAB 01 já tem um registro **curinga** `*.$KUBEFORGE_HOST`
apontando para o IP do server. Então **qualquer subdomínio já resolve pro cluster** — o Girus
usa `girus.$KUBEFORGE_HOST` sem precisar de nenhum registro novo. O Traefik
roteia pelo header `Host:`, e o Let's Encrypt valida (HTTP-01) porque o wildcard resolve.

> **Padrão da trilha:** cada serviço futuro ganha `<nome>.$KUBEFORGE_HOST`
> de graça pelo wildcard. Confirme que resolve: `dig +short girus.$KUBEFORGE_HOST`
> deve devolver o IP do server. (O wildcard cobre **um** nível de subdomínio.)

## Como subir

```bash
export KUBECONFIG=~/.kube/config-kubeforge

# 1. Defina o hostname UMA vez (na raiz do repo): copie kubeforge.env.example
#    para kubeforge.env e preencha KUBEFORGE_HOST com o SEU host (o do LAB 01).
#    NÃO edite os YAML à mão — o ./configure.sh materializa o host no passo 3.

# 2. Plataforma (namespace, RBAC, backend, frontend, services, nginx):
kubectl apply -f 01-girus-platform.yaml

# 3. Ingress + TLS — SEM auth ainda (o basic-auth travaria o desafio HTTP-01):
(cd ../.. && ./configure.sh)      # gera 02-girus-ingress.rendered.yaml com o host
kubectl apply -f 02-girus-ingress.rendered.yaml

# 4. ESPERE o cert ficar Ready (HTTP-01, ~1-2 min). Só siga quando READY=True:
kubectl -n girus get certificate girus-frontend-tls -w
#    (Ctrl-C quando aparecer READY=True)

# 5. AUTENTICAÇÃO (só depois do cert!): gera a senha aleatória + Secrets.
#    Imprime a senha e o comando de recuperá-la. GUARDE a senha.
./setup-auth.sh                    # usuário 'girus' + senha aleatória
#    (ou: ./setup-auth.sh -u marcelo)

# 6. Cria o Middleware de basic-auth:
kubectl apply -f 03-girus-auth.yaml

# 7. LIGA o auth no Ingress (annotation) — agora sim, cert já emitido:
kubectl -n girus annotate ingress girus-frontend \
  traefik.ingress.kubernetes.io/router.middlewares=girus-girus-basic-auth@kubernetescrd \
  --overwrite
```

Acesse: `https://girus.$KUBEFORGE_HOST` — o browser abre um **popup de
login** (basic-auth do Traefik). Usuário/senha são os que o `setup-auth.sh`
imprimiu. Para recuperar a senha a qualquer momento, no cluster:

```bash
kubectl -n girus get secret girus-auth-password -o jsonpath='{.data.password}' | base64 -d; echo
```

> **Por que auth só no passo 7?** O cert-manager valida o domínio via HTTP-01
> batendo em `http://.../.well-known/acme-challenge/...`, que passa pelo mesmo
> Ingress. Se o basic-auth já estiver ligado, o Traefik responde 401 nesse path e
> a emissão do certificado **trava**. Ligue o auth só com o cert `Ready`. Se um
> dia a renovação empacar, desligue o auth temporariamente (remova a annotation
> com o sufixo `-`), renove, e religue.

## Carregar os labs

Os labs do Girus são **ConfigMaps** (`kind: ConfigMap` com o `lab.yaml` dentro),
e os nossos vivem em [`labs/`](labs/). São **11 labs** adaptados/criados para o
nosso k3s ARM64 e validados no cluster real — **8 de Kubernetes** (`kube-NN`) e
**3 de Linux opcionais** (`linux-NN`):

| # | Arquivo | Tema |
|---|---------|------|
| 1 | `labs/kube-01-deployment.yaml` | Deployments — criar, escalar, atualizar, rollback |
| 2 | `labs/kube-02-services-redes.yaml` | Services e Redes — ClusterIP, NodePort, EndpointSlice, proxy |
| 3 | `labs/kube-03-configmaps-secrets.yaml` | ConfigMaps e Secrets — config, dados sensíveis, volumes, TLS |
| 4 | `labs/kube-04-cronjobs.yaml` | CronJobs — agendamento, ciclo de vida, Jobs |
| 5 | `labs/kube-05-exploracao-recursos.yaml` | Exploração — namespaces, troubleshooting, limpeza seletiva |
| 6 | `labs/kube-06-helm.yaml` | Helm — empacotamento: chart, install/upgrade/rollback (teoria em [`docs/helm.md`](../../docs/helm.md)) |
| 7 | `labs/kube-07-kustomize.yaml` | Kustomize — configuração por ambiente sem templates: base + overlays, `apply -k` |
| 8 | `labs/kube-08-volumes-persistentes.yaml` | Volumes — PV/PVC, hostPath (RWO), NFS (RWX) |
| — | `labs/linux-01-processamento-texto.yaml` | **[Opcional]** Linux — grep, sed, awk |
| — | `labs/linux-02-permissoes-arquivos.yaml` | **[Opcional]** Linux — permissões, chmod, umask |
| — | `labs/linux-03-shell-script.yaml` | **[Opcional]** Linux — shell script Bash |

**Suba todos os labs de uma vez** (o `-f labs/` aplica o diretório inteiro) e
recarregue o backend para ele detectá-los:

```bash
export KUBECONFIG=~/.kube/config-kubeforge
kubectl apply -f labs/                                # sobe TODOS os labs de uma vez
kubectl -n girus rollout restart deployment/girus-backend
kubectl -n girus rollout status  deployment/girus-backend --timeout=90s
```

Depois disso, os 11 labs aparecem na UI do Girus e você vai fazendo cada um pela
plataforma. Para **reaplicar um lab** que você editou, aplique só ele
(`kubectl apply -f labs/kube-06-helm.yaml`) + o mesmo `rollout restart`.

> Depois de (re)aplicar labs, **inicie uma sessão nova** do lab na UI — o Girus
> tira um snapshot da validação no início da sessão; recarregar a aba não atualiza
> uma sessão já em andamento.

> **Editar labs:** as armadilhas de autoria (render do painel, validação por
> igualdade exata, RBAC da SA do aluno, etc.) estão documentadas no tutor da
> trilha, em [`skills/kubeforge-tutor/references/gotchas.md`](../../skills/kubeforge-tutor/references/gotchas.md).

## Segurança / RBAC — leia antes de usar

Dois controles protegem o cluster, porque o ambiente de lab tem poder de criar
workloads:

**1. RBAC do aluno com menor privilégio.** O manifesto **original** do Girus
concede **`cluster-admin` GLOBAL** à SA de lab (`lab-test-user/default`). Num Kind
descartável, tudo bem; **neste cluster que persiste, é risco desnecessário.**
Trocamos por um ClusterRole **`girus-lab-operator`**: amplo nos recursos de
workload que os labs usam (namespaces, pods, deployments, services, configmaps,
secrets, jobs, cronjobs, ingress, netpol, RBAC **namespaced**, leitura de nós),
mas **SEM** os poderes perigosos de cluster (nós, PVs, CRDs, webhooks, RBAC de
cluster, escrita em kube-system). Se um lab futuro precisar de mais, conceda o
mínimo adicional a ELE — ou, conscientemente, troque o `roleRef` de
`girus-lab-operator` por `cluster-admin` (é a alternativa "igual ao upstream").

**2. Autenticação de borda (basic-auth).** Como o ambiente cria containers no
cluster, expor o Girus na internet SEM login deixaria qualquer um criar workloads.
Um Middleware Traefik (`03-girus-auth.yaml`) exige **usuário + senha** antes de
rotear para o frontend — sem tocar no Girus (nada de fork). A senha é uma **chave
aleatória** gerada pelo `setup-auth.sh` e guardada em Secret:
- `girus-basic-auth`    → `usuario:hash-bcrypt` (consumido pelo Traefik)
- `girus-auth-password` → senha em texto (para recuperar)

Recuperar a senha:
```bash
kubectl -n girus get secret girus-auth-password -o jsonpath='{.data.password}' | base64 -d; echo
```
Trocar a senha: rode `./setup-auth.sh` de novo (regenera) e reaplique nada mais —
o Traefik relê o Secret. Para rotacionar o usuário: `./setup-auth.sh -u <novo>`.

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
