# LAB 03 — Helm (empacotamento)

> Terceiro laboratório da trilha [KubeForge](../README.md). Empacota o app **whoami**
> (o mesmo do [LAB 02](../lab-02/README.md)) como um **Helm chart**: um template, N
> configurações via `values`. Ensina `install` / `upgrade` / `rollback` — o que o
> `kubectl apply` de YAML solto não dá.
>
> **Pré-requisito:** cluster do [LAB 01](../lab-01/README.md) no ar e o cert-manager +
> issuers do [LAB 02](../lab-02/README.md) instalados (o chart reusa o `letsencrypt-prod`).

## 1. Objetivo

Transformar YAML solto em um **chart reutilizável e versionado**, e dominar o ciclo de vida
de um release: instalar, atualizar (mudando `values`), consultar histórico e **reverter**.

```text
YAML solto → helm chart (Chart.yaml + values + templates) → install → upgrade → rollback
```

## 2. Por que Helm (e não `kubectl apply`)

| `kubectl apply -f` | Helm |
|---|---|
| YAML fixo, copiado/editado por ambiente | **1 template + `values`** por ambiente |
| sem versão do "pacote" | **chart versionado** (SemVer) + histórico de releases |
| rollback = você reverte à mão | **`helm rollback`** em 1 comando |
| sem visão do conjunto | **release** agrupa todos os objetos |

## 3. Anatomia do chart (o que tem em `charts/whoami/`)

```text
charts/whoami/
  Chart.yaml              metadados: nome, version (do chart), appVersion (do app)
  values.yaml             os "botões": replicaCount, image, resources, ingress...
  templates/
    _helpers.tpl          nome + labels reutilizados (não repetir)
    deployment.yaml       Deployment parametrizado por .Values
    service.yaml          Service
    ingress.yaml          Ingress+TLS (condicional em ingress.enabled)
```

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

Veja o YAML que o chart gera, sem tocar no cluster:
```bash
cd lab-03
helm lint charts/whoami                    # valida o chart
helm template whoami charts/whoami         # imprime os manifests renderizados
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
helm install whoami charts/whoami --set ingress.host=kubeforge-<iniciais>.ddnsgeek.com
helm list                                  # release 'whoami' STATUS=deployed
kubectl get deploy,svc,ingress -l app.kubernetes.io/instance=whoami
```

## 7. Upgrade (mudar `values` sem reescrever YAML)

Suba de 2 para 3 réplicas — o superpoder do `values`:
```bash
helm upgrade whoami charts/whoami \
  --set ingress.host=kubeforge-<iniciais>.ddnsgeek.com \
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

## 10. Validar automaticamente

```bash
export KUBECONFIG=~/.kube/config-kubeforge
./tests/verify.sh
```
Checa: release `deployed`, Deployment com as réplicas do `values` prontas, Service existe,
label `managed-by=Helm`, e histórico com upgrade (revisão ≥ 2). 🎉 se tudo passar.

## Limpeza

```bash
helm uninstall whoami       # remove todos os objetos do release de uma vez
```
