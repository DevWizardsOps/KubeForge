# Helm — empacotamento de aplicações (documentação de referência)

> Material de referência da trilha [KubeForge](../README.md) sobre **Helm**. O
> **lab interativo** de Helm agora roda dentro da plataforma **Girus** (Fase 1/2)
> — ver [`platform/girus-on-k3s/labs/lab-helm.yaml`](../platform/girus-on-k3s/labs/lab-helm.yaml).
> Este documento é o "porquê" e a teoria (conceitos, anatomia do chart, sintaxe
> de template) que complementam a prática guiada no Girus.
>
> O exemplo usado aqui — o app **whoami** empacotado como chart — está preservado
> em [`docs/examples/helm-whoami-chart/`](examples/helm-whoami-chart/) e reusa o
> Ingress+TLS do [LAB 02](../lab-02/README.md) (issuer `letsencrypt-prod`).

## 1. Objetivo

Transformar YAML solto em um **chart reutilizável e versionado**, e dominar o ciclo de vida
de um release: instalar, atualizar (mudando `values`), consultar histórico e **reverter**.

```text
YAML solto → helm chart (Chart.yaml + values + templates) → install → upgrade → rollback
```

## 2. Por que Helm (e não `kubectl apply`)

![Helm: o gerenciador de pacotes para Kubernetes — três pilares (Chart, Repository, Release), arquitetura (Helm Client, Helm Library em Go, estado no cluster via Secrets) e o que permite fazer (instalar apps prontos, parametrizar por ambiente, upgrade/rollback, dependências)](images/helm-overview.png)

Os **três pilares** (esquerda da imagem): **Chart** é o pacote (equivale a `.deb`/RPM ou
fórmula do Homebrew); **Repository** é onde charts são compartilhados (ex.: Artifact Hub);
**Release** é uma instância do chart rodando no cluster — dá pra instalar o mesmo chart N vezes,
cada uma um release independente. O estado de cada release fica em **Secrets nativos** do
cluster (sem banco próprio — o Helm 3 dispensou o Tiller).

| `kubectl apply -f` | Helm |
|---|---|
| YAML fixo, copiado/editado por ambiente | **1 template + `values`** por ambiente |
| sem versão do "pacote" | **chart versionado** (SemVer) + histórico de releases |
| rollback = você reverte à mão | **`helm rollback`** em 1 comando |
| sem visão do conjunto | **release** agrupa todos os objetos |

## 3. Anatomia do chart (o que tem em `docs/examples/helm-whoami-chart/`)

```text
helm-whoami-chart/
  Chart.yaml              metadados: nome, version (do chart), appVersion (do app)
  values.yaml             os "botões": replicaCount, image, resources, ingress...
  templates/
    _helpers.tpl          nome + labels reutilizados (não repetir)
    deployment.yaml       Deployment parametrizado por .Values
    service.yaml          Service
    ingress.yaml          Ingress+TLS (condicional em ingress.enabled)
```

### Como um template vira YAML (a mágica do Helm)

Um arquivo em `templates/` **não é YAML fixo** — é um molde. O trecho `{{ ... }}` é
substituído pelo motor de template (Go templates) com os dados do `values.yaml`. Exemplo,
o `templates/deployment.yaml`:

```yaml
spec:
  replicas: {{ .Values.replicaCount }}          # ← vem do values.yaml
  ...
      containers:
        - name: whoami
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          resources:
            {{- toYaml .Values.resources | nindent 12 }}   # bloco inteiro do values
```

Com `values.yaml` = `replicaCount: 2`, `image.tag: v1.10.3`, o Helm **renderiza**:

```yaml
spec:
  replicas: 2
  ...
      containers:
        - name: whoami
          image: "traefik/whoami:v1.10.3"
          resources:
            requests: { cpu: 10m, memory: 16Mi }
            limits:   { cpu: 100m, memory: 64Mi }
```

**A sintaxe que aparece no chart:**

| Construção | O que faz |
|---|---|
| `{{ .Values.x }}` | injeta um valor do `values.yaml` (ou do `--set x=`) |
| `{{ .Release.Name }}` | nome do release (`helm install <nome> ...`) — variável embutida |
| `{{ include "whoami.labels" . }}` | insere um bloco definido no `_helpers.tpl` (DRY) |
| `{{- toYaml .Values.resources }}` | serializa um sub-objeto do values como YAML |
| `\| nindent 12` | reindenta o bloco com 12 espaços (encaixa no lugar certo) |
| `{{- if .Values.ingress.enabled }}` | renderiza o Ingress **só se** `enabled: true` |
| `{{-` / `-}}` | o `-` "come" o espaço em branco em volta (YAML limpo) |

O `_helpers.tpl` guarda pedaços reutilizáveis (nome, labels) para os 3 templates não
repetirem a mesma expressão — é o `include` acima que os puxa. **Um template, N `values`:**
é isso que substitui manter vários YAMLs por ambiente.

## 4. Instalar o Helm

```bash
# macOS
brew install helm
# Linux
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
# Windows: winget install Helm.Helm   (ou use WSL2)
helm version
```

## 5. Renderizar antes de aplicar (dry-run)

Veja o YAML que o chart gera, sem tocar no cluster (a partir da raiz do repo):
```bash
CHART=docs/examples/helm-whoami-chart
helm lint $CHART                           # valida o chart
helm template whoami $CHART                # imprime os manifests renderizados
```

## 6. Instalar o release

> ⚠️ **Se você fez o LAB 02 aplicando os manifests com `kubectl apply`:** o Deployment,
> Service e Ingress **`whoami`** já existem no cluster sem os metadados do Helm. O
> `helm install` se recusa a adotá-los (`invalid ownership metadata`). **Limpe antes:**
> ```bash
> kubectl delete -f lab-02/manifests/02-whoami-app.yaml
> kubectl delete -f lab-02/manifests/03-whoami-ingress.yaml
> ```
> O cert-manager e os ClusterIssuers ficam — o chart reusa o `letsencrypt-prod`.

```bash
export KUBECONFIG=~/.kube/config-kubeforge
# TROQUE o host pelo SEU (o do DDNS do LAB 01):
helm install whoami $CHART --set ingress.host=$KUBEFORGE_HOST
helm list                                  # release 'whoami' STATUS=deployed
kubectl get deploy,svc,ingress -l app.kubernetes.io/instance=whoami
```

## 7. Upgrade (mudar `values` sem reescrever YAML)

Suba de 2 para 3 réplicas — o superpoder do `values`:
```bash
helm upgrade whoami $CHART \
  --set ingress.host=$KUBEFORGE_HOST \
  --set replicaCount=3
kubectl get pods -l app.kubernetes.io/instance=whoami   # agora 3 pods
helm history whoami                        # revisão 2 aparece
```

## 8. Rollback (o que YAML solto não faz)

```bash
helm rollback whoami 1                      # volta à revisão 1 (2 réplicas)
kubectl get pods -l app.kubernetes.io/instance=whoami   # de volta a 2 pods
helm history whoami                         # revisão 3 = rollback registrado
```

## 9. Resultado esperado

- `helm list` → release `whoami` **deployed**.
- Objetos com label `app.kubernetes.io/managed-by=Helm` (vieram do chart).
- Ciclo `install → upgrade → rollback` exercitado (histórico com ≥ 2 revisões).
- App servido no mesmo HTTPS do LAB 02 (o chart reusa o Ingress+TLS).

## 10. Prática guiada e validação automática (no Girus)

A validação automática deste conteúdo agora vive no **lab interativo de Helm da
plataforma Girus** — [`platform/girus-on-k3s/labs/lab-helm.yaml`](../platform/girus-on-k3s/labs/lab-helm.yaml).
Lá o aluno exercita `helm create → install → upgrade → rollback → uninstall` no
terminal do browser e cada tarefa é validada na hora (✅/❌), sem precisar de
`verify.sh` local. Este documento é a referência teórica; o Girus é a prática.

## Limpeza

```bash
helm uninstall whoami       # remove todos os objetos do release de uma vez
```
