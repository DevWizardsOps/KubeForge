# Guia de ensino — LAB 03: Helm (empacotamento)

README do lab: `~/git/KubeForge/lab-03/README.md`

## O conceito em uma frase

Helm é o **gerenciador de pacotes** do Kubernetes: transforma YAML fixo num **template
parametrizável** (chart) com **ciclo de vida** (install/upgrade/rollback) e **versão**.

## O problema antes da ferramenta (comece por aqui)

Pergunte ao aluno: *"você tem o whoami do LAB 02. Como você sobe ele em dev com 1 réplica
e em prod com 3, sem manter dois YAMLs?"* — a dor do copy-paste de YAML é o gancho. O Helm
responde: **um template, dois `values`**.

## Diagrama mental (antes de digitar)

```text
values.yaml  ──┐
   --set    ──┼─▶ [motor de template Helm] ─▶ manifests renderizados ─▶ release no cluster
templates/  ──┘                                                            │
                                                    helm history / rollback ┘  (cada apply = 1 revisão)
```

## Roteiro (o que fazer, na ordem)

1. **Mostre o problema:** `kubectl apply` de YAML solto não versiona nem reverte.
2. **Anatomia:** abra `Chart.yaml` (version do chart × appVersion do app), `values.yaml`
   (os botões), `templates/` (o molde). O `_helpers.tpl` existe para não repetir labels.
3. **Dry-run primeiro:** `helm template` mostra o YAML final SEM tocar no cluster — sempre
   renderize antes de instalar. `helm lint` valida o chart.
4. **Install → upgrade → rollback:** o ciclo que prova o valor. `--set replicaCount=3` num
   upgrade e depois `helm rollback` de volta.
5. **Prove:** `./tests/verify.sh` (release deployed, réplicas certas, revisão ≥ 2).

## Perguntas que provam entendimento

- "Qual a diferença entre `version` e `appVersion` no Chart.yaml?"
  (chart = embalagem; appVersion = o software dentro dela.)
- "Por que rodar `helm template` antes de `helm install`?"
  (ver o YAML real antes de aplicar — pega erro de template cedo.)
- "O que o `helm rollback` faz que o `kubectl apply` não faz?"
  (volta o release inteiro a uma revisão anterior conhecida, num comando.)
- "Onde muda o número de réplicas — no template ou no values?"
  (no values; o template só referencia `.Values.replicaCount`.)

## Onde a turma trava (gotchas)

- **Esquece o `--set ingress.host`** → o cert tenta emitir para `kubeforge-mwl` (o default
  do values) e o Ingress não bate com o DDNS do aluno. Sempre passar o host próprio.
- **Confunde nome do release com nome do chart** → `helm install <release> <chart>`; o
  primeiro é o nome da instância, o segundo é o caminho/pacote.
- **`helm upgrade` sem repassar os `--set`** → valores não-persistidos voltam ao default.
  (Ou use `-f values-prod.yaml`, ou repasse os `--set`, ou `--reuse-values`.)

## Como este lab evoluiu

Reusa o whoami do LAB 02 de propósito — o aluno já conhece o app, então o foco fica 100%
no Helm (empacotamento), não em entender um app novo. Encadeia para os próximos:
Kustomize (overlay sem template) e ArgoCD/Flux (GitOps sobre o chart).
