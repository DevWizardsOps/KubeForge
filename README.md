# KubeForge

Trilha prática de **Kubernetes Cloud Native**, com foco em **ARM64** e custo zero (ou quase),
organizada em **duas fases**: **Fase 1** — aprender os primitivos do Kubernetes (via a
plataforma GIRUS rodando no nosso cluster); **Fase 2** — melhorar a entrega de software com
as ferramentas do ecossistema (Helm, GitOps, etc.). A infra (LAB 01 + LAB 02) sobe o cluster
e o HTTPS real onde as duas fases acontecem. Visão completa em **[docs/ROADMAP.md](docs/ROADMAP.md)**.

## Fundação (LAB 01) — AWS Academy + k3s

Cluster **k3s multi-node** (1 server + N agents) sobre **EC2 Graviton (ARM64)** no
**AWS Academy Learner Lab**, provisionado por Terraform. Sem cartão, sem custo de control
plane (k3s roda nas próprias EC2), <US$1/sessão de crédito do Learner Lab.

➡️ **[LAB 01 — AWS Academy + k3s](lab-01/README.md)**

> **Nota histórica:** a trilha começou na Oracle Cloud (OKE + Ampere A1 Always Free), mas o
> A1 ficou cronicamente `Out of host capacity` em São Paulo (set/2026). Pivotamos para AWS
> Academy + k3s, que dá um cluster ARM64 real e gratuito sem depender de estoque. O caminho
> OCI foi removido do repo para não confundir a trilha.

## Estrutura

```text
lab-01/     Fundação — AWS Academy + k3s ARM64 (Terraform + DDNS)
lab-02/     Certificado TLS (cert-manager + Let's Encrypt) — provedor-agnóstico
lab-03/     Helm (empacotamento) — chart do whoami, install/upgrade/rollback
lab-NN/     Kubernetes padrão (agnóstico de provedor)
platform/   Plataforma da Fase 1 — GIRUS on k3s (aprendizado interativo de k8s)
docs/       ROADMAP e documentação de referência
skills/     Skill-tutor da trilha (ensino)
```

➡️ **[LAB 02 — Certificado TLS (cert-manager + Let's Encrypt)](lab-02/README.md)** — HTTPS
válido no hostname DDNS.
➡️ **[LAB 03 — Helm (empacotamento)](lab-03/README.md)** — empacota o whoami como chart.

## Validação dos labs (check scripts)

Cada lab traz um **`tests/verify.sh`** que checa o estado real do cluster e diz na hora
se o desafio foi resolvido — ✅ por item, ou ❌ com o que faltou. É o mesmo papel do
*check script* de plataformas como Instruqt/Killercoda, mas **versionado no repo e custo
zero**, rodando contra o seu próprio k3s:

```bash
export KUBECONFIG=~/.kube/config-kubeforge
cd lab-01 && ./tests/verify.sh    # 🎉 se tudo passar; exit 1 listando o que falta
```

Os helpers ficam em [`.ci/verify-lib.sh`](.ci/verify-lib.sh) (`check`, `check_eq`,
`check_contains`, `summary`). Um lab novo só escreve os checks específicos.

## Tutor da trilha (skill)

O repo inclui uma **skill de ensino** em [`skills/kubeforge-tutor/`](skills/kubeforge-tutor/SKILL.md)
— ajuda quem faz os labs a entender cada conceito e quem ensina a conduzir (método, guias por
lab, perguntas de checagem, e um `gotchas.md` com os erros reais). Para usá-la como skill viva
no Kiro Crew, faça um symlink dela em `~/.kiro/skills/`:
```bash
ln -s "$(pwd)/skills/kubeforge-tutor" ~/.kiro/skills/kubeforge-tutor
```

## Convenções

- **ARM64 first** — imagens e charts preferem `arm64`; o material assume esse alvo.
- **Ambiente testado: macOS.** Comandos podem variar em Linux/Windows (use **WSL2** para os
  scripts `.sh`). Pré-requisitos por SO em cada lab (ex.: [account-setup do LAB 01](lab-01/docs/account-setup/README.md)).
- **Sem segredos no Git** — `*.tfvars`, `*.tfstate`, `*.pem` e credenciais são ignorados.

## Créditos de terceiros

- **GIRUS** — a plataforma de aprendizado interativo da **Fase 1** é um projeto
  open-source da **[LINUXtips](https://linuxtips.io)**
  ([github.com/badtuxx/girus-cli](https://github.com/badtuxx/girus-cli)),
  licenciado sob **GPL-3.0**. Nós apenas o hospedamos no nosso cluster para fins de
  estudo; todo o crédito da plataforma é da LINUXtips e seus contribuidores. Os
  arquivos derivados em [`platform/girus-on-k3s/`](platform/girus-on-k3s/README.md)
  herdam a GPL-3.0 e declaram as modificações feitas.
