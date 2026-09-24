# Ferramentas e Pré-requisitos (instalação por SO)

> Parte do **LAB 01** do [KubeForge](../../README.md). Reutilizável por toda a
> trilha — instale estas ferramentas uma vez.
>
> ⚠️ **Os comandos deste projeto foram testados no macOS.** Onde o comando muda
> em Linux/Windows, está indicado abaixo. Em Windows, prefira **WSL2** (Ubuntu)
> para rodar os scripts `.sh` da trilha — vários deles são bash e **não** rodam
> no PowerShell nativo.

## O que você precisa

| Ferramenta | Para quê | Labs |
|---|---|---|
| **Terraform** ≥ 1.5 | Provisionar infra (VCN, OKE, compute) | 01+ |
| **OCI CLI** | Gerar kubeconfig, consultar versões/imagens, credenciais | 02+ |
| **kubectl** | Falar com o cluster Kubernetes | 02+ |
| **jq** | Processar JSON nos scripts/exemplos | vários |
| **git**, **bash** | Versionar e rodar os scripts | todos |

---

## macOS (Homebrew) — ambiente de referência deste projeto

```bash
brew install terraform kubectl jq
# OCI CLI:
brew install oci-cli
# (alternativa oficial, se não usar brew:)
# bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

## Linux (Ubuntu/Debian)

```bash
# Terraform (repo HashiCorp)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform jq

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl

# OCI CLI
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

## Windows

Duas opções. **Recomendado: WSL2** — instale o Ubuntu e siga a seção Linux acima.
Os scripts `.sh` da trilha (ex.: `gen-tfvars.sh`) só rodam em bash/WSL, **não** no
PowerShell.

```powershell
# WSL2 (uma vez):
wsl --install -d Ubuntu
# depois, dentro do Ubuntu, siga a seção Linux.
```

Se preferir Windows nativo (sem WSL), use o **winget** — mas você terá de fazer o
passo do `gen-tfvars.sh` manualmente (ver README do lab-02, "Windows / manual"):

```powershell
winget install HashiCorp.Terraform
winget install Kubernetes.kubectl
winget install Oracle.OCICLI
winget install jqlang.jq
```

---

## Verificar a instalação

```bash
terraform version
oci --version
kubectl version --client
jq --version
```

## Configurar a autenticação da OCI CLI

O OCI CLI usa o mesmo `~/.oci/config` + API Key da
[credencial do Terraform](../api-credentials/README.md). Se já configurou aquilo,
o CLI funciona. Para (re)configurar interativamente:

```bash
oci setup config
```

> No Windows nativo o config fica em `%USERPROFILE%\.oci\config`; no WSL/macOS/Linux,
> em `~/.oci/config`.
