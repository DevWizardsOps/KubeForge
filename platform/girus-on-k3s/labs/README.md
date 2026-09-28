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

| # | Arquivo | Ensina |
|---|---|---|
| 1 | `lab-deployment.yaml` | Deployment (réplicas, imagem, labels), Service, ConfigMap como volume |
| 2 | `lab-services-redes.yaml` | Services, ClusterIP, seletores, DNS interno |
| 3 | `lab-configmaps-secrets.yaml` | ConfigMap/Secret, env vs volume |
| 4 | `lab-cronjobs.yaml` | CronJob, Job, agendamento |
| 5 | `lab-exploracao-recursos.yaml` | describe/logs/pods/deploy — inspeção de recursos |

## Como carregar

Os labs são **ConfigMaps** no namespace `girus`; o backend do Girus os detecta.

```bash
export KUBECONFIG=~/.kube/config-kubeforge
# carrega todos de uma vez:
kubectl apply -f labs/
# ou um por vez:
kubectl apply -f labs/lab-deployment.yaml
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
