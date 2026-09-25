variable "region" {
  description = "Região AWS (Learner Lab: só us-east-1 ou us-west-2)."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil do AWS CLI com a credencial do Learner Lab (ex.: kubeforge). Vazio usa o default/AWS_PROFILE."
  type        = string
  default     = "kubeforge"
}

variable "instance_type" {
  description = "Tipo EC2 (ARM64/Graviton). t4g.large = 2 vCPU / 8 GB — confirmado liberado pela SCP via dry-run."
  type        = string
  default     = "t4g.large"
}

variable "agent_count" {
  description = "Número de nós agent (workers) além do server. 1 = cluster de 2 nós; 2 = cluster de 3 nós."
  type        = number
  default     = 2

  validation {
    condition     = var.agent_count >= 0 && var.agent_count <= 4
    error_message = "agent_count deve ficar entre 0 e 4 (teto de 32 vCPU do Learner Lab; cada t4g.large = 2 vCPU)."
  }
}

variable "disk_gb" {
  description = "Tamanho do disco raiz gp3 em GB (Learner Lab exige < 100)."
  type        = number
  default     = 30

  validation {
    condition     = var.disk_gb > 0 && var.disk_gb < 100
    error_message = "disk_gb deve ser < 100 (limite de EBS do Learner Lab)."
  }
}

variable "key_name" {
  description = "Nome do key pair EC2 para SSH. No Learner Lab é 'vockey' (a PEM baixada em AWS Details)."
  type        = string
  default     = "vockey"
}

variable "vpc_cidr" {
  description = "CIDR da VPC nova."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública."
  type        = string
  default     = "10.0.1.0/24"
}

variable "my_ip_cidr" {
  description = "Seu IP público em CIDR (ex.: 203.0.113.4/32) para liberar SSH/6443/NodePort. NUNCA use 0.0.0.0/0."
  type        = string
}

variable "expose_web" {
  description = "Abre 80/443 ao público (0.0.0.0/0) para o Ingress e o desafio ACME HTTP-01 do Let's Encrypt (LAB 03). false mantém o cluster fechado ao seu IP."
  type        = bool
  default     = false
}

# --- Dynu DDNS (atualização automática do IP do server) --------------------
# O server instala um systemd timer que reporta o IP público ao Dynu no boot e
# a cada 5 min (IP Update Protocol). O hostname é adicionado ao --tls-san do
# k3s, então o cert nasce válido para o nome e o kubeconfig usa
# https://<hostname>:6443 (nunca mais 'sed' de IP entre sessões).
#
# CAMINHO FÁCIL: preencha owner_initials (ex.: "mwl") e o hostname é montado
# como kubeforge-<owner_initials>.<dynu_domain>. Deixe owner_initials vazio ("")
# para desligar o DDNS por completo.
variable "owner_initials" {
  description = "Suas iniciais para compor o hostname DDNS (ex.: 'mwl' -> kubeforge-mwl.ddnsgeek.com). Vazio desliga o DDNS. O hostname resultante deve já existir no Dynu."
  type        = string
  default     = ""

  validation {
    condition     = var.owner_initials == "" || can(regex("^[a-z0-9-]{1,20}$", var.owner_initials))
    error_message = "owner_initials deve conter só letras minúsculas, dígitos ou hífen (1-20 chars), ou ficar vazio."
  }
}

variable "dynu_domain" {
  description = "Domínio DDNS base (o que você tem no Dynu). Compõe kubeforge-<owner_initials>.<dynu_domain>."
  type        = string
  default     = "ddnsgeek.com"
}

variable "dynu_hostname" {
  description = "OVERRIDE opcional do hostname completo. Se preenchido, ganha de owner_initials/dynu_domain. Use só se o padrão kubeforge-<iniciais>.<domínio> não servir."
  type        = string
  default     = ""
}

variable "dynu_password" {
  description = "IP Update Password do Dynu (Control Panel > seu hostname > IP Update Password), NÃO a senha da conta. Vai ao user_data (legível na console EC2) — por isso use a senha DEDICADA e revogável. Ponha no terraform.tfvars (gitignored)."
  type        = string
  default     = ""
  sensitive   = true
}
