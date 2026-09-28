# KubeForge — Roadmap da trilha

A trilha tem **duas grandes fases**. A ideia pedagógica central: você **sofre o
primitivo** primeiro (Fase 1) e **depois** vê a ferramenta que resolve aquela dor
(Fase 2) — o paralelo "por que isso importa" é o que faz a ferramenta fazer
sentido, em vez de virar comando decorado.

```text
Infra de plataforma        Fase 1 — Aprender Kubernetes      Fase 2 — Entregar software
─────────────────────      ────────────────────────────      ──────────────────────────
LAB 01  provisiona k3s  →   GIRUS on k3s (primitivos:     →   Helm, Kustomize, ArgoCD/Flux,
LAB 02  TLS (HTTPS real)    Pods, Deploy, Services,           secrets, observabilidade,
        ↓                   ConfigMap/Secret, ...)            network policies, Harbor,
   sobe a plataforma                                          backup/DR, serverless...
```

## Infra de plataforma (pré-requisito das duas fases)

| Item | O quê | Estado |
|---|---|---|
| **LAB 01** | AWS Academy + k3s ARM64 (Terraform + DDNS) | ✅ pronto |
| **LAB 02** | Certificado TLS (cert-manager + Let's Encrypt) | ✅ pronto |

Estes dois sobem o cluster e o HTTPS real. O Girus roda **no** cluster do LAB 01
e ganha URL HTTPS via LAB 02.

## Fase 1 — Aprender Kubernetes (via GIRUS)

A plataforma [GIRUS](https://github.com/badtuxx/girus-cli) (LINUXtips) roda no
nosso k3s e entrega os labs de **primitivos** de forma interativa (terminal no
browser + validação automática). Setup em
[`platform/girus-on-k3s/`](../platform/girus-on-k3s/README.md).

Primitivos a cobrir (curadoria dos labs do Girus pendente):
- Pods & Deployments (ReplicaSet, rollout/rollback nativo)
- Services & Redes (ClusterIP/NodePort, DNS interno, Ingress)
- ConfigMaps & Secrets (e a dor do base64)
- Exploração de recursos (kubectl, describe, logs, exec)
- Storage & State (PV/PVC/StorageClass, StatefulSet) — *checar se o Girus cobre*
- Scheduling & Health (labels/selectors, affinity, probes) — *checar cobertura*

> **Por que Girus e não README+verify.sh:** o Girus já entrega a experiência
> interativa e a validação que queríamos (era o que atraía no Instruqt), custo
> zero, no nosso ambiente. Economiza escrever os labs de fundação do zero.
>
> **Créditos:** GIRUS é um projeto open-source da
> [LINUXtips](https://linuxtips.io) ([github.com/badtuxx/girus-cli](https://github.com/badtuxx/girus-cli)),
> licença **GPL-3.0**. Nós apenas o hospedamos no nosso cluster para estudo — todo
> o crédito da plataforma é da LINUXtips. Detalhes em
> [`platform/girus-on-k3s/`](../platform/girus-on-k3s/README.md).

## Fase 2 — Entregar software (labs numerados)

Com a base de k8s dominada, entram as ferramentas de **entrega**. Ordem por
dependência (empacotar → versionar por ambiente → automatizar → operar):

| Lab | Tema | Estado |
|---|---|---|
| **Helm** | empacotamento — **migrado para lab interativo no Girus** (`platform/girus-on-k3s/labs/lab-helm.yaml`); teoria em `docs/helm.md` | ✅ pronto |
| LAB 04 | Kustomize (overlays sem template) | planejado |
| LAB 05 | ArgoCD / Flux (GitOps) | planejado |
| LAB 06+ | Gerenciamento de Segredos (Sealed Secrets / Vault) | planejado |
| ... | Observabilidade (Prometheus/Grafana Operator) | planejado |
| ... | Redes: Network Policies, Admission Policies | planejado |
| ... | Versionamento de imagens (build + registry), Harbor + cache | planejado |
| ... | Backup & DR, storage (NFS, CEPH) | planejado |
| ... | GitLab Runner (CI no cluster) | planejado |
| ... | Serverless (Knative) | planejado |

Cada lab da Fase 2 abre com o **gancho** para a Fase 1: "lembra quando você fez X
na mão? Agora a ferramenta Y resolve isso."

## Backlog / ideias

- **Lab de comparação de tipos de deployment** — Deployment vs StatefulSet vs
  DaemonSet; estratégias rolling vs recreate vs blue-green/canary. Lab avançado,
  entra na Fase 2 depois que a fundação existir. (Ideia registrada em 2026-09-28.)

## Convenções (ver README raiz)

- **ARM64 first** · **ambiente testado macOS** · **sem segredos no Git**.
- Cada lab numerado traz `tests/verify.sh` (check script versionado, custo zero).
