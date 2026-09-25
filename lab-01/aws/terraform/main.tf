###############################################################################
# KubeForge — LAB 01 (Opção A): k3s multi-node no AWS Academy Learner Lab
#
# Sobe uma VPC nova + N instâncias EC2 Graviton (ARM64) rodando k3s:
#   - 1 server  (control-plane + worker)
#   - agent_count agents (workers)
#
# Desenho pensado para o Learner Lab:
#   - SEM NAT Gateway e SEM ELB (os dois vilões que cobram entre sessões e
#     drenam o budget de US$50). As instâncias ficam em subnet PÚBLICA com IGW.
#   - Elastic IP no server: o IP público muda a cada restart de 4h; o EIP fixa
#     o endpoint do k3s API e o SSH.
#   - Comunicação entre nós por IP PRIVADO (estável dentro da VPC), então o
#     reset de 4h não quebra o cluster.
#
# IAM: usa só o que o Learner Lab já concede (LabRole). Não cria roles/policies.
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region
  # profile: passe -var 'aws_profile=kubeforge' ou exporte AWS_PROFILE.
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      Project = "KubeForge"
      Lab     = "lab-01-aws"
      Managed = "terraform"
    }
  }
}

# AMI Ubuntu 24.04 ARM64 mais recente (mesma família que passou no dry-run).
data "aws_ami" "ubuntu_arm64" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Guard: o teto ARM garantido/observado é t4g.large; barra tipos absurdos e
# instância x86 sem querer (a premissa do projeto é ARM64).
locals {
  is_arm = can(regex("^(t4g|m6g|c6g|r6g|m7g|c7g|r7g)\\.", var.instance_type))

  # Hostname DDNS efetivo: override explícito ganha; senão compõe das iniciais;
  # senão vazio (DDNS desligado).
  dynu_hostname = (
    var.dynu_hostname != "" ? var.dynu_hostname :
    var.owner_initials != "" ? "kubeforge-${var.owner_initials}.${var.dynu_domain}" :
    ""
  )
}

resource "terraform_data" "arch_guard" {
  lifecycle {
    precondition {
      condition     = local.is_arm
      error_message = "instance_type '${var.instance_type}' não é Graviton/ARM64. A premissa do KubeForge é ARM64 (t4g/m6g/...). Se a SCP negar ARM, ajuste conscientemente."
    }
  }
}

###############################################################################
# Rede
###############################################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "kubeforge-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "kubeforge-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  tags                    = { Name = "kubeforge-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "kubeforge-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# Security Group
###############################################################################

resource "aws_security_group" "k3s" {
  name        = "kubeforge-k3s-sg"
  description = "k3s cluster: SSH + API + intra-node"
  vpc_id      = aws_vpc.this.id

  # SSH — só da sua origem (nunca 0.0.0.0/0).
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # k3s API — da sua origem, para usar kubectl de fora da EC2.
  ingress {
    description = "k3s API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # Tráfego intra-cluster (server <-> agents) — só dentro da VPC.
  ingress {
    description = "intra-node (all)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # NodePort — da sua origem, para expor serviços de teste.
  ingress {
    description = "NodePort range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    description = "all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "kubeforge-k3s-sg" }
}

###############################################################################
# Token compartilhado do k3s (server <-> agents)
###############################################################################

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

###############################################################################
# EC2 — server
###############################################################################

resource "aws_instance" "server" {
  depends_on             = [terraform_data.arch_guard]
  ami                    = data.aws_ami.ubuntu_arm64.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k3s.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = var.disk_gb
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/templates/server-userdata.sh.tftpl", {
    k3s_token     = random_password.k3s_token.result
    dynu_hostname = local.dynu_hostname
    dynu_password = var.dynu_password
  })

  tags = { Name = "kubeforge-k3s-server", Role = "server" }
}

# Elastic IP fixo no server (endpoint estável do k3s API entre resets de 4h).
resource "aws_eip" "server" {
  instance = aws_instance.server.id
  domain   = "vpc"
  tags     = { Name = "kubeforge-k3s-server-eip" }
}

###############################################################################
# EC2 — agents (workers)
###############################################################################

resource "aws_instance" "agent" {
  depends_on             = [terraform_data.arch_guard]
  count                  = var.agent_count
  ami                    = data.aws_ami.ubuntu_arm64.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k3s.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = var.disk_gb
    volume_type = "gp3"
  }

  # O agent usa o IP PRIVADO do server (estável dentro da VPC).
  user_data = templatefile("${path.module}/templates/agent-userdata.sh.tftpl", {
    k3s_token  = random_password.k3s_token.result
    server_url = "https://${aws_instance.server.private_ip}:6443"
  })

  tags = { Name = "kubeforge-k3s-agent-${count.index + 1}", Role = "agent" }
}
