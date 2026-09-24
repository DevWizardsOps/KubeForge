# Gerar a Credencial de API para o Terraform (OCI)

> Parte do **LAB 01 — OCI Foundation** do projeto [KubeForge](../../README.md).
> Pré-requisito para rodar o Terraform em [`../../terraform/`](../../terraform/README.md).

O Terraform OCI Provider **não** usa usuário/senha. Ele autentica com uma
**API Signing Key**: um par de chaves RSA cuja **chave pública** é registrada no
seu usuário OCI e cuja **chave privada** fica no seu Mac. Cada requisição é
assinada com a chave privada; a Oracle valida com a pública.

Você vai coletar **cinco** informações:

| Campo Terraform | O que é |
|---|---|
| `tenancy_ocid` | OCID do tenancy (a "conta raiz") |
| `user_ocid` | OCID do seu usuário |
| `fingerprint` | Impressão digital da API Key gerada |
| `private_key_path` | Caminho local da chave privada (`~/.oci/oci_api_key.pem`) |
| `region` | `sa-saopaulo-1` (Brazil East / São Paulo) |

> 🔒 **Segurança:** a chave privada e o `terraform.tfvars` **nunca** vão para o Git.
> O [`.gitignore`](../../../.gitignore) do repositório já bloqueia `.oci/`, `*.pem`,
> `*.key` e `*.tfvars`.

---

## Opção A — Gerar pelo Console (recomendado)

### 1. Abrir o perfil do usuário

No **OCI Console** (região São Paulo), clique no ícone de perfil no canto superior
direito → **My profile**.

Ainda nessa página, copie o **OCID** do usuário (botão *Copy* ao lado de *OCID*) —
esse é o seu `user_ocid`.

### 2. Adicionar a API Key

Na coluna **Resources** (à esquerda) → **API keys** → **Add API key**.

Escolha **Generate API key pair** e clique em:

1. **Download private key** → salve o arquivo (ex.: `oci_api_key.pem`).
2. (Opcional) **Download public key**.
3. **Add**.

### 3. Copiar o Configuration File Preview

Após adicionar, a Oracle mostra um **Configuration File Preview** — um bloco pronto
como este:

```ini
[DEFAULT]
user=ocid1.user.oc1..aaaa...
fingerprint=aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99
tenancy=ocid1.tenancy.oc1..aaaa...
region=sa-saopaulo-1
key_file=<path to your private keyfile>   # substitua depois
```

**Copie esse bloco inteiro.** Ele já traz `user`, `fingerprint`, `tenancy` e
`region`. Se fechar a tela, o fingerprint também fica listado em **API keys**.

### 4. Instalar as credenciais no Mac

```bash
mkdir -p ~/.oci
# mova a chave privada baixada:
mv ~/Downloads/oci_api_key.pem ~/.oci/oci_api_key.pem
# cole o Configuration File Preview em ~/.oci/config e ajuste o key_file:
#   key_file=~/.oci/oci_api_key.pem
$EDITOR ~/.oci/config

# permissões restritas (a OCI recusa chave "world-readable"):
chmod 600 ~/.oci/oci_api_key.pem
chmod 600 ~/.oci/config
```

### 5. (Opcional) Validar com o OCI CLI

```bash
oci iam region list   # se retornar a lista, a credencial está válida
```

---

## Opção B — Gerar a chave por linha de comando

Se preferir criar o par você mesmo e só registrar a **pública** no Console:

```bash
mkdir -p ~/.oci && chmod 700 ~/.oci

# chave privada RSA 2048 (sem passphrase para uso não-interativo do Terraform)
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
chmod 600 ~/.oci/oci_api_key.pem

# chave pública correspondente (é ESTA que você cola no Console)
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem

# fingerprint (o mesmo que o Console mostra)
openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem 2>/dev/null \
  | openssl md5 -c | awk '{print $2}'
```

No Console: **My profile → API keys → Add API key → Paste public key** e cole o
conteúdo de `~/.oci/oci_api_key_public.pem`. Copie o `user`/`tenancy`/`region` da
tela do perfil.

---

## 6. Preencher o Terraform

```bash
cd lab-01/oci/terraform
cp example.tfvars terraform.tfvars
$EDITOR terraform.tfvars
```

`terraform.tfvars` (LOCAL, ignorado pelo git):

```hcl
tenancy_ocid     = "ocid1.tenancy.oc1..aaaa..."
user_ocid        = "ocid1.user.oc1..aaaa..."
fingerprint      = "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99"
private_key_path = "~/.oci/oci_api_key.pem"
region           = "sa-saopaulo-1"
compartment_ocid = ""   # vazio = tenancy root
```

Testar:

```bash
terraform init
terraform plan -var-file=terraform.tfvars
```

Um `plan` que lista os recursos da VCN a serem criados confirma que a credencial
funciona.

---

## Cost Considerations

Gerar API Key e coletar OCIDs é **gratuito**. Nenhum recurso pago é criado.

## Troubleshooting

| Erro | Causa | Ação |
|---|---|---|
| `401-NotAuthenticated` | fingerprint ou key errados | Conferir se o fingerprint bate com o da API key e se `key_file` aponta para a chave certa |
| `Private key must be in PEM format` | chave criptografada/errada | Gerar RSA sem passphrase (Opção B) |
| `The required information to complete authentication was not provided` | falta campo no `~/.oci/config` ou `.tfvars` | Preencher os 5 campos |
| `key_file ... permissions are too open` | `chmod` errado | `chmod 600 ~/.oci/oci_api_key.pem` |
| `~` não expande no `private_key_path` | shell/HCL não expandiu | Usar caminho absoluto (`/Users/<você>/.oci/...`) |

## ARM64 Compatibility

**ARM64 Compatible: N/A** — geração de credencial não envolve arquitetura de compute.
