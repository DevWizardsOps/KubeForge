# Labs de fundamentos de Kubernetes (Fase 1)

Labs de **conceitos de Kubernetes** para carregar na plataforma GIRUS (ver
[`../README.md`](../README.md)). São os labs de *workloads e recursos* — o aluno
mexe em Deployment, Service, ConfigMap/Secret, CronJob **no nosso k3s real**, não
num cluster de brinquedo.

> **Por que estes e não os labs "fundamentos/kind" do Girus:** os labs de
> fundamentos do Girus sobem um **Kind aninhado** (cluster dentro do pod) — cluster
> de brinquedo, isolado. Estes labs de conceito **não** fazem isso: rodam `kubectl`
> contra o cluster hospedeiro (o nosso k3s) via a ServiceAccount `girus-sa`. É o
> que queremos — praticar nos primitivos reais.

## Ordem sugerida

Os arquivos usam dois prefixos de sequência independentes — `kube-NN` (fundamentos
de Kubernetes) e `linux-NN` (fundamentos de Linux, **opcionais**) — para que as duas
trilhas cresçam sem colidir na numeração.

### Trilha Kubernetes (`kube-NN`)

| # | Arquivo | Ensina |
|---|---|---|
| 1 | `kube-01-deployment.yaml` | Deployment (réplicas, imagem, labels), Service, ConfigMap como volume |
| 2 | `kube-02-services-redes.yaml` | Services, ClusterIP, seletores, DNS interno |
| 3 | `kube-03-configmaps-secrets.yaml` | ConfigMap/Secret, env vs volume |
| 4 | `kube-04-cronjobs.yaml` | CronJob, Job, agendamento |
| 5 | `kube-05-exploracao-recursos.yaml` | describe/logs/pods/deploy — inspeção de recursos |
| 6 | `kube-06-helm.yaml` | Helm — chart, install/upgrade/rollback |
| 7 | `kube-07-kustomize.yaml` | Kustomize — base + overlays, `apply -k` |
| 8 | `kube-08-volumes-persistentes.yaml` | PV/PVC, hostPath (RWO), NFS (RWX) |

### Trilha Linux (`linux-NN`, opcional)

Labs de fundamentos de **Linux** (título prefixado com `[Opcional]`), adaptados para
rodar na imagem `alpine/k8s:1.33.1` (ARM64) usada no terminal do aluno.

| # | Arquivo | Ensina |
|---|---|---|
| 1 | `linux-01-processamento-texto.yaml` | grep, sed, awk — busca, substituição, colunas |
| 2 | `linux-02-permissoes-arquivos.yaml` | chmod, octal, umask, propriedade |
| 3 | `linux-03-shell-script.yaml` | Bash — variáveis, argumentos, loops, condicionais, funções |

## Como carregar

Os labs são **ConfigMaps** no namespace `girus`; o backend do Girus os detecta.

```bash
export KUBECONFIG=~/.kube/config-kubeforge
# carrega todos de uma vez:
kubectl apply -f labs/
# ou um por vez:
kubectl apply -f labs/kube-01-deployment.yaml
```

Depois, na interface do Girus (`https://girus.$KUBEFORGE_HOST`),
os labs aparecem na lista para iniciar.

## Ponto a verificar ao aplicar (honesto)

A imagem do ambiente do aluno foi trocada para **`rancher/kubectl:v1.33.13`**
(multi-arch, roda no ARM64) porque a original do Girus
(`linuxtips/girus-kind-single-node:0.1` / `girus-devops:0.1`) é **amd64-only** e
não sobe no Graviton. A `rancher/kubectl` é **enxuta** (só o binário `kubectl`).

Se algum passo de um lab precisar de **shell/editor** (`vim`, `nano`, `bash`) ou de
outra ferramenta, o pod-terminal enxuto pode não atender — nesse caso, trocar o
`image:` do lab por uma imagem ARM64 com `kubectl` + shell. **Isso só o teste no
cluster confirma** (o cluster hiberna a cada 4h no Learner Lab).

## Créditos e licença

Conteúdo (tasks e validações) **adaptado** do
[girus-cli](https://github.com/badtuxx/girus-cli) da **[LINUXtips](https://linuxtips.io)**,
licença **GPL-3.0**. Cada arquivo traz o cabeçalho de atribuição e a modificação
feita (troca da imagem para ARM64). Todo o crédito do conteúdo é da LINUXtips e
seus contribuidores.
