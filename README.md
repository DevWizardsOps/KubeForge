# KubeForge

Trilha prática de **Kubernetes Cloud Native** em 30 labs, com foco em **ARM64** e custo zero
(ou quase). A trilha oferece **dois caminhos de fundação** para subir o cluster — escolha um
nos labs 01-02; do LAB 03 em diante tudo é Kubernetes padrão, agnóstico de provedor.

## Caminhos de fundação (labs 01-02)

### ✅ Opção A — AWS Academy + k3s (ATIVA)

Cluster **k3s single-node** sobre uma **EC2 do AWS Academy Learner Lab**, preferindo
**Graviton (ARM64)**. Sem cartão, sem custo de control plane (k3s roda na própria EC2).

➡️ **[LAB 01 — AWS Academy + k3s](lab-01/aws/README.md)**

### ⚠️ Opção B — Oracle Cloud / OKE (ALTERNATIVA)

Cluster **OKE gerenciado** com node pool **Ampere A1 (ARM64) Always Free**. Código válido,
mas **bloqueado em set/2026 por `Out of host capacity`** do A1 em São Paulo — o cluster sobe,
o node pool não acha estoque. Use quando a Oracle liberar capacidade.

➡️ **[LAB 01 — OCI Foundation (rede)](lab-01/oci/README.md)** → **[LAB 02 — OKE](lab-02/README.md)**

## Comparação

| | Opção A (AWS Academy) | Opção B (OCI/OKE) |
|---|---|---|
| **Status** | ✅ ativa | ⚠️ bloqueada (estoque A1) |
| **Cluster** | k3s single-node (EC2) | OKE gerenciado |
| **ARM64** | Graviton (se SCP permitir) | Ampere A1 (nativo) |
| **Custo** | crédito US$100 (só a EC2) | Always Free (zero) |
| **Persistência** | EC2 para/volta (reset 4 h) | contínua |
| **Fundação** | 1 lab (conta + cluster) | 2 labs (rede + OKE) |

## Estrutura

```text
lab-01/
  aws/     Opção A — AWS Academy + k3s (ativa)
  oci/     Opção B — fundação de rede OCI
lab-02/    Opção B — cluster OKE (depende de lab-01/oci)
lab-03+/   Kubernetes padrão (agnóstico de provedor)
```

## Convenções

- **ARM64 first** — imagens e charts preferem `arm64`; o material assume esse alvo.
- **Ambiente testado: macOS.** Comandos podem variar em Linux/Windows (use **WSL2** para os
  scripts `.sh`). Pré-requisitos por SO: [Ferramentas](lab-01/oci/docs/prerequisites/README.md).
- **Sem segredos no Git** — `*.tfvars`, `*.tfstate`, `*.pem` e credenciais são ignorados.
