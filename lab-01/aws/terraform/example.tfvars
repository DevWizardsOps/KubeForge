# KubeForge — LAB 01 AWS: exemplo de variáveis.
# Copie para terraform.tfvars e ajuste. terraform.tfvars é ignorado pelo git.

# Região (Learner Lab: us-east-1 ou us-west-2).
region = "us-east-1"

# Perfil do AWS CLI com a credencial do Learner Lab (AWS Details > AWS CLI: Show).
# A credencial é temporária e expira a cada sessão de 4h — reconfigure quando reabrir.
aws_profile = "kubeforge"

# Tipo ARM64/Graviton confirmado liberado pela SCP (dry-run OK).
# t4g.large = 2 vCPU / 8 GB. Alternativa menor: t4g.medium (2 vCPU / 4 GB).
instance_type = "t4g.large"

# Nós agent além do server:
#   1 => cluster de 2 nós (1 server + 1 agent)  ~4 vCPU
#   2 => cluster de 3 nós (1 server + 2 agents) ~6 vCPU  (default, folga p/ labs pesados)
agent_count = 2

# Disco raiz (Learner Lab exige < 100 GB).
disk_gb = 30

# Key pair do Learner Lab. O padrão do lab é "vockey" (baixe a PEM em AWS Details > Download PEM).
key_name = "vockey"

# SEU IP público em CIDR /32 — libera SSH/6443/NodePort só para você.
# Descubra com:  curl -s https://checkip.amazonaws.com
# NUNCA use 0.0.0.0/0.
my_ip_cidr = "SEU.IP.PUBLICO.AQUI/32"

# Rede (padrões OK; mude só se colidir com algo seu).
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"

# LAB 03 (TLS/Ingress): abre 80/443 ao público para o Ingress e o desafio
# ACME HTTP-01 do Let's Encrypt. Deixe false até chegar no LAB 03.
expose_web = false

# --- Dynu DDNS (opcional, mas recomendado para o reset de 4h) ---------------
# O server atualiza um hostname DDNS sozinho no boot e a cada 5 min. Assim o
# kubeconfig usa https://<hostname>:6443 e você NÃO troca o IP toda sessão.
#
# CAMINHO FÁCIL: só ponha suas INICIAIS. O hostname vira kubeforge-<iniciais>.<domínio>.
# O hostname resultante precisa JÁ EXISTIR no Dynu (crie o A record antes).
# Deixe owner_initials vazio ("") para desligar o DDNS.
owner_initials = "mwl"            # -> kubeforge-mwl.ddnsgeek.com
dynu_domain    = "ddnsgeek.com"   # troque se você usa outro domínio no Dynu

# OVERRIDE opcional: se quiser um hostname completo fora do padrão acima,
# preencha dynu_hostname (ganha das iniciais). Deixe vazio para usar o padrão.
# dynu_hostname = "meu-nome-custom.exemplo.com"

# IP Update Password do Dynu — Control Panel > (seu hostname) > IP Update Password.
# NÃO é a senha da conta: é uma senha DEDICADA a updates de IP, revogável.
# Use ela (não a senha da conta) porque o user_data é legível na console EC2.
dynu_password = "SUA_IP_UPDATE_PASSWORD_AQUI"
