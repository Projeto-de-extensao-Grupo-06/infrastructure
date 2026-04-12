# Documento de Implementação Cloud - Solarway

## Visão Geral

Este documento descreve a implementação corrigida da infraestrutura Terraform para deploy na AWS, abordando todos os problemas identificados na arquitetura anterior.

---

## 1. Arquitetura Corrigida

### 1.1 Diagrama da Nova Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS CLOUD (us-east-1)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        VPC: 10.0.0.0/24                              │   │
│  │                                                                      │   │
│  │  ┌─────────────────────┐         ┌─────────────────────────────────┐ │   │
│  │  │   SUBNET PUBLICA    │         │         SUBNETS PRIVADAS        │ │   │
│  │  │   10.0.0.0/28       │         │                                 │ │   │
│  │  │                     │         │  ┌─────────┐  ┌─────────┐      │ │   │
│  │  │  ┌───────────────┐  │◄────────┤  │ Frontend│  │ Backend │      │ │   │
│  │  │  │   NGINX       │  │  SSH     │  │  -1     │  │  -1     │      │ │   │
│  │  │  │   PROXY       │  │          │  │ (8081)  │  │ (8000)  │      │ │   │
│  │  │  │               │  │          │  └─────────┘  └─────────┘      │ │   │
│  │  │  │ + NAT ROLE    │  │          │  ┌─────────┐  ┌─────────┐      │ │   │
│  │  │  │   (iptables)  │  │◄────────┤  │ Frontend│  │ Backend │      │ │   │
│  │  │  └───────────────┘  │  SSH     │  │  -2     │  │  -2     │      │ │   │
│  │  │         │           │          │  │ (8080)  │  │ (8082)  │      │ │   │
│  │  │         │           │          │  └─────────┘  └─────────┘      │ │   │
│  │  │    ┌────▼────┐      │          │  ┌─────────┐  ┌─────────┐      │ │   │
│  │  │    │Internet │      │◄────────┤  │   DB    │  │  Bots   │      │ │   │
│  │  │    │ Gateway │      │  SSH     │  │(3306/  │  │(3000/   │      │ │   │
│  │  │    └─────────┘      │          │  │ 6379)   │  │ 5678)   │      │ │   │
│  │  └─────────────────────┘          │  └─────────┘  └─────────┘      │ │   │
│  │                                    └─────────────────────────────────┘ │   │
│  │                                                                       │   │
│  │  LEGENDA CONEXÕES:                                                    │   │
│  │  ───► HTTP/HTTPS (80/443) para internet                              │   │
│  │  ──►  Proxy para aplicações (via upstream nginx)                     │   │
│  │  ──►  NAT para internet (via iptables forwarding)                    │   │
│  │  ──►  SSH via Bastion (porta 22)                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Mudanças Principais

| Aspecto | Antes | Depois |
|---------|-------|--------|
| Acesso Internet (Privado) | Sem acesso | Via NAT no Proxy |
| Docker Networks | External (quebrava) | Criadas automaticamente |
| Deploy Ordem | Paralelo problemático | Sequencial com healthchecks |
| SG Banco | Aberto para VPC | Restrito ao SG do Backend |
| Envio de Arquivos | .env manual | Template + provisioners |
| Chave SSH (.pem) | Hardcoded `solarway` | Variável `AWS_KEY_NAME` no `.env` |

---

## 2. Configuração Terraform Corrigida

### 2.1 Módulo VPC (`terraform/modules/vpc/main.tf`)

```hcl
# Adicionar ao final do arquivo

# ── Elastic IP para NAT Instance ───────────────────────────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "solarway-nat-eip-${var.environment}"
    Environment = var.environment
  }
}

# ── Route Table Privada com NAT ──────────────────────────────────────────────
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  # Rota padrão via NAT Instance (será configurada no main de prod)

  tags = {
    Name        = "solarway-private-rt-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ── NACL Privada Corrigida (apenas tráfego interno + retorno NAT) ────────────
resource "aws_network_acl" "private" {
  count      = length(var.private_subnets)
  vpc_id     = aws_vpc.this.id
  subnet_ids = [aws_subnet.private[count.index].id]

  # Entrada: permitir tráfego da VPC apenas
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr  # Apenas tráfego interno da VPC
    from_port  = 0
    to_port    = 0
  }

  # Entrada: permitir tráfego retorno da internet (NAT)
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535  # Portas efêmeras para retorno
  }

  # Saída: permitir tudo (via NAT)
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "solarway-nacl-private-${count.index}"
    Environment = var.environment
  }
}
```

### 2.2 Novo Módulo Security Groups (`terraform/modules/security-groups/main.tf`)

Criar novo arquivo para SGs específicos:

```hcl
# terraform/modules/security-groups/main.tf

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

# ── SG do Proxy (Bastion + NAT) ──────────────────────────────────────────────
resource "aws_security_group" "proxy" {
  name        = "solarway-sg-proxy-${var.environment}"
  description = "Proxy Nginx - HTTP/HTTPS/SSH"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH from anywhere"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "solarway-sg-proxy-${var.environment}"
    Environment = var.environment
  }
}

# ── SG do Banco de Dados ────────────────────────────────────────────────────
resource "aws_security_group" "database" {
  name        = "solarway-sg-db-${var.environment}"
  description = "Database - MySQL e Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
    description     = "MySQL from backend only"
  }

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
    description     = "Redis from backend only"
  }

  # SSH apenas via proxy (bastion)
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
    description     = "SSH via bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "solarway-sg-db-${var.environment}"
    Environment = var.environment
  }
}

# ── SG do Backend ──────────────────────────────────────────────────────────
resource "aws_security_group" "backend" {
  name        = "solarway-sg-backend-${var.environment}"
  description = "Backend applications"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
    description     = "API from proxy"
  }

  ingress {
    from_port       = 8082
    to_port         = 8082
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
    description     = "Microservice from proxy"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
    description     = "SSH via bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "solarway-sg-backend-${var.environment}"
    Environment = var.environment
  }
}

# ── SG do Frontend ─────────────────────────────────────────────────────────
resource "aws_security_group" "frontend" {
  name        = "solarway-sg-frontend-${var.environment}"
  description = "Frontend applications"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
    description     = "Management from proxy"
  }

  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
    description     = "Institutional from proxy"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
    description     = "SSH via bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "solarway-sg-frontend-${var.environment}"
    Environment = var.environment
  }
}

# ── SG dos Bots ────────────────────────────────────────────────────────────
resource "aws_security_group" "bots" {
  name        = "solarway-sg-bots-${var.environment}"
  description = "Bot services"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
    description     = "Bot API from proxy"
  }

  ingress {
    from_port       = 5678
    to_port         = 5678
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
    description     = "n8n from proxy"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
    description     = "SSH via bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "solarway-sg-bots-${var.environment}"
    Environment = var.environment
  }
}

# Outputs
output "proxy_sg_id" { value = aws_security_group.proxy.id }
output "db_sg_id" { value = aws_security_group.database.id }
output "backend_sg_id" { value = aws_security_group.backend.id }
output "frontend_sg_id" { value = aws_security_group.frontend.id }
output "bots_sg_id" { value = aws_security_group.bots.id }
```

### 2.3 Módulo EC2 Corrigido (`terraform/modules/ec2/main.tf`)

```hcl
# terraform/modules/ec2/main.tf

resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name != "" ? var.key_name : null
  iam_instance_profile   = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  user_data = var.user_data != "" ? var.user_data : null

  # Habilitar source/dest check = false para NAT Instance
  source_dest_check = var.enable_nat ? false : true

  tags = merge({
    Name        = "solarway-ec2-${var.instance_name}-${var.environment}"
    Environment = var.environment
  }, var.extra_tags)
}

# Variables atualizadas
variable "security_group_ids" {
  description = "Lista de SG IDs"
  type        = list(string)
}

variable "volume_size" {
  description = "Tamanho do disco em GB"
  type        = number
  default     = 20
}

variable "enable_nat" {
  description = "Desabilitar source/dest check para NAT"
  type        = bool
  default     = false
}

variable "extra_tags" {
  description = "Tags adicionais"
  type        = map(string)
  default     = {}
}

# Outputs
output "instance_id" { value = aws_instance.this.id }
output "private_ip" { value = aws_instance.this.private_ip }
output "public_ip" {
  value = var.subnet_id == "" ? "" : aws_instance.this.public_ip
}
```

---

## 3. Main.tf de Produção Corrigido

### 3.1 Estrutura Completa (`terraform/environments/prod/main.tf`)

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MÓDULO VPC
# ═══════════════════════════════════════════════════════════════════════════════
module "vpc_prod" {
  source = "../../modules/vpc"

  environment = "prod"
  vpc_cidr    = "10.0.0.0/24"

  public_subnets  = ["10.0.0.0/28"]
  private_subnets = [
    "10.0.0.16/28",  # Frontend-1 (Institucional)
    "10.0.0.32/28",  # Frontend-2 (Management)
    "10.0.0.48/28",  # Backend-1 (Monolith)
    "10.0.0.64/28",  # Backend-2 (Microservice)
    "10.0.0.80/28",  # Database
    "10.0.0.96/28",  # Bots
  ]

  azs = ["us-east-1a", "us-east-1a", "us-east-1a", "us-east-1a", "us-east-1a", "us-east-1a", "us-east-1a"]
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY GROUPS
# ═══════════════════════════════════════════════════════════════════════════════
module "security_groups" {
  source = "../../modules/security-groups"

  environment = "prod"
  vpc_id      = module.vpc_prod.vpc_id
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTÂNCIA PROXY (Pública + NAT)
# ═══════════════════════════════════════════════════════════════════════════════
module "ec2_nginx" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "nginx-proxy"
  instance_type  = "t3.small"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.public_subnet_ids[0]
  key_name       = var.key_name
  security_group_ids = [module.security_groups.proxy_sg_id]

  enable_nat = true  # Necessário para funcionar como NAT

  user_data = templatefile("../../../scripts/setup/prod/userdata-proxy.sh", {
    environment = "prod"
  })
}

# ── Configurar NAT no Proxy após criação ─────────────────────────────────────
resource "aws_route" "private_nat" {
  route_table_id         = module.vpc_prod.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = module.ec2_nginx.instance_id

  depends_on = [module.ec2_nginx]
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTÂNCIA DATABASE (Privada)
# ═══════════════════════════════════════════════════════════════════════════════
module "ec2_db" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "database"
  instance_type  = "t3.large"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[4]
  key_name       = var.key_name
  security_group_ids = [module.security_groups.db_sg_id]
  iam_instance_profile = "LabInstanceProfile"
  volume_size    = 50  # Mais espaço para banco

  user_data = templatefile("../../../scripts/setup/prod/userdata-db.sh", {
    environment = "prod"
  })

  depends_on = [aws_route.private_nat]  # Só criar depois que NAT estiver pronto
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTÂNCIAS BACKEND (Privadas)
# ═══════════════════════════════════════════════════════════════════════════════
module "ec2_backend_1" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "backend-monolith"
  instance_type  = "t3.medium"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[2]
  key_name       = var.key_name
  security_group_ids = [module.security_groups.backend_sg_id]
  iam_instance_profile = "LabInstanceProfile"

  user_data = templatefile("../../../scripts/setup/prod/userdata-backend.sh", {
    backend_type = "monolith"
  })

  depends_on = [module.ec2_db]
}

module "ec2_backend_2" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "backend-microservice"
  instance_type  = "t3.medium"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[3]
  key_name       = var.key_name
  security_group_ids = [module.security_groups.backend_sg_id]
  iam_instance_profile = "LabInstanceProfile"

  user_data = templatefile("../../../scripts/setup/prod/userdata-backend.sh", {
    backend_type = "microservice"
  })

  depends_on = [module.ec2_db]
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTÂNCIAS FRONTEND (Privadas)
# ═══════════════════════════════════════════════════════════════════════════════
module "ec2_frontend_1" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "frontend-institucional"
  instance_type  = "t3.small"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[0]
  key_name       = var.key_name
  security_group_ids = [module.security_groups.frontend_sg_id]
  iam_instance_profile = "LabInstanceProfile"

  user_data = templatefile("../../../scripts/setup/prod/userdata-frontend.sh", {
    frontend_type = "institutional"
  })

  depends_on = [module.ec2_backend_1]
}

module "ec2_frontend_2" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "frontend-management"
  instance_type  = "t3.small"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[1]
  key_name       = var.key_name
  security_group_ids = [module.security_groups.frontend_sg_id]
  iam_instance_profile = "LabInstanceProfile"

  user_data = templatefile("../../../scripts/setup/prod/userdata-frontend.sh", {
    frontend_type = "management"
  })

  depends_on = [module.ec2_backend_1]
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTÂNCIAS BOTS (Privadas)
# ═══════════════════════════════════════════════════════════════════════════════
module "ec2_chatbot" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "chatbot"
  instance_type  = "t3.small"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[5]
  key_name       = var.key_name
  security_group_ids = [module.security_groups.bots_sg_id]
  iam_instance_profile = "LabInstanceProfile"

  user_data = templatefile("../../../scripts/setup/prod/userdata-bot.sh", {
    bot_type = "chatbot"
  })

  depends_on = [module.ec2_db]
}

module "ec2_webscraping" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "webscraping"
  instance_type  = "t3.micro"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[5]
  key_name       = var.key_name
  security_group_ids = [module.security_groups.bots_sg_id]
  iam_instance_profile = "LabInstanceProfile"

  user_data = templatefile("../../../scripts/setup/prod/userdata-bot.sh", {
    bot_type = "webscraping"
  })

  depends_on = [module.ec2_db]
}
```

---

## 4. User Data Scripts Corrigidos

### 4.1 User Data do Proxy (`scripts/setup/prod/userdata-proxy.sh`)

```bash
#!/bin/bash
# ==============================================================================
# User Data: Proxy Nginx + NAT Instance
# ==============================================================================
set -e

exec > >(tee -a /var/log/solarway-init.log|logger -t solarway-init -s 2>/dev/console) 2>&1
export DEBIAN_FRONTEND=noninteractive

echo "➡️ [PROXY-INIT] Iniciando setup do Proxy/NAT..."

# ── Atualizar sistema ───────────────────────────────────────────────────────
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release iptables-persistent netfilter-persistent

# ── Configurar IP Forwarding (NAT) ────────────────────────────────────────────
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# ── Configurar iptables para NAT ────────────────────────────────────────────
# Mascarar tráfego da VPC para internet
iptables -t nat -A POSTROUTING -o eth0 -s 10.0.0.0/24 -j MASQUERADE
iptables -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -o eth0 -j ACCEPT

# Salvar regras
iptables-save > /etc/iptables/rules.v4

# ── Instalar Docker ───────────────────────────────────────────────────────────
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    apt-get install -y docker-compose-plugin
fi

systemctl enable docker
systemctl start docker

usermod -aG docker ubuntu

# ── Criar redes Docker ────────────────────────────────────────────────────────
# Aguardar Docker estar pronto
while ! docker info >/dev/null 2>&1; do sleep 2; done

# Criar network do proxy (será usada por todos)
docker network create solarway_network 2>/dev/null || true

echo "✅ [PROXY-INIT] Setup base concluído! Aguardando deploy via Terraform..."
```

### 4.2 User Data do Database (`scripts/setup/prod/userdata-db.sh`)

```bash
#!/bin/bash
# ==============================================================================
# User Data: Database (MySQL + Redis)
# ==============================================================================
set -e

exec > >(tee -a /var/log/solarway-db.log|logger -t solarway-db -s 2>/dev/console) 2>&1
export DEBIAN_FRONTEND=noninteractive

echo "➡️ [DB-INIT] Iniciando setup do Database..."

# ── Atualizar e instalar dependências ───────────────────────────────────────
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release netcat

# ── Instalar Docker ───────────────────────────────────────────────────────────
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    apt-get install -y docker-compose-plugin
fi

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# ── Aguardar Docker ───────────────────────────────────────────────────────────
while ! docker info >/dev/null 2>&1; do sleep 2; done

# ── Criar diretório da aplicação ─────────────────────────────────────────────
mkdir -p /opt/solarway/services/db
mkdir -p /opt/solarway/scripts
chown -R ubuntu:ubuntu /opt/solarway

echo "✅ [DB-INIT] Setup base concluído! Aguardando arquivos via Terraform..."
```

### 4.3 User Data do Backend (`scripts/setup/prod/userdata-backend.sh`)

```bash
#!/bin/bash
# ==============================================================================
# User Data: Backend (Monolith/Microservice)
# ==============================================================================
set -e

exec > >(tee -a /var/log/solarway-backend.log|logger -t solarway-backend -s 2>/dev/console) 2>&1
export DEBIAN_FRONTEND=noninteractive

BACKEND_TYPE="${backend_type}"

echo "➡️ [BACKEND-INIT] Iniciando setup do Backend ($BACKEND_TYPE)..."

# ── Atualizar e instalar Docker ──────────────────────────────────────────────
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    apt-get install -y docker-compose-plugin
fi

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# ── Aguardar Docker ───────────────────────────────────────────────────────────
while ! docker info >/dev/null 2>&1; do sleep 2; done

# ── Criar diretórios ───────────────────────────────────────────────────────────
mkdir -p /opt/solarway/services/backend
mkdir -p /opt/solarway/scripts
chown -R ubuntu:ubuntu /opt/solarway

echo "✅ [BACKEND-INIT] Setup base concluído! Aguardando arquivos via Terraform..."
```

### 4.4 User Data do Frontend (`scripts/setup/prod/userdata-frontend.sh`)

```bash
#!/bin/bash
# ==============================================================================
# User Data: Frontend (Institutional/Management)
# ==============================================================================
set -e

exec > >(tee -a /var/log/solarway-frontend.log|logger -t solarway-frontend -s 2>/dev/console) 2>&1
export DEBIAN_FRONTEND=noninteractive

FRONTEND_TYPE="${frontend_type}"

echo "➡️ [FRONTEND-INIT] Iniciando setup do Frontend ($FRONTEND_TYPE)..."

apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    apt-get install -y docker-compose-plugin
fi

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

while ! docker info >/dev/null 2>&1; do sleep 2; done

mkdir -p /opt/solarway/services/frontend
mkdir -p /opt/solarway/scripts
chown -R ubuntu:ubuntu /opt/solarway

echo "✅ [FRONTEND-INIT] Setup base concluído! Aguardando arquivos via Terraform..."
```

### 4.5 User Data do Bot (`scripts/setup/prod/userdata-bot.sh`)

```bash
#!/bin/bash
# ==============================================================================
# User Data: Bots (Chatbot/Webscraping)
# ==============================================================================
set -e

exec > >(tee -a /var/log/solarway-bot.log|logger -t solarway-bot -s 2>/dev/console) 2>&1
export DEBIAN_FRONTEND=noninteractive

BOT_TYPE="${bot_type}"

echo "➡️ [BOT-INIT] Iniciando setup do Bot ($BOT_TYPE)..."

apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    apt-get install -y docker-compose-plugin
fi

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

while ! docker info >/dev/null 2>&1; do sleep 2; done

mkdir -p /opt/solarway/services/bot
mkdir -p /opt/solarway/scripts
chown -R ubuntu:ubuntu /opt/solarway

echo "✅ [BOT-INIT] Setup base concluído! Aguardando arquivos via Terraform..."
```

---

## 5. Deploy.tf Corrigido

### 5.1 Estrutura Completa (`terraform/environments/prod/deploy.tf`)

```hcl
# ═══════════════════════════════════════════════════════════════════════════════
# TEMPLATES DE CONFIGURAÇÃO
# ═══════════════════════════════════════════════════════════════════════════════

locals {
  # Aguardar instâncias estarem prontas
  db_ready     = module.ec2_db.private_ip != ""
  backend_ready = module.ec2_backend_1.private_ip != ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPLOY: DATABASE
# ═══════════════════════════════════════════════════════════════════════════════
resource "null_resource" "deploy_db" {
  triggers = {
    instance_id = module.ec2_db.instance_id
    env_hash    = md5(templatefile("${path.module}/templates/env.db.tmpl", {
      db_password         = var.db_password
      redis_password      = var.redis_password
      github_username     = var.github_username
      github_access_token = var.github_token
    }))
  }

  connection {
    type                = "ssh"
    user                = "ubuntu"
    private_key         = file("${path.module}/../../../${var.key_name}.pem")
    host                = module.ec2_db.private_ip
    bastion_host        = module.ec2_nginx.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("${path.module}/../../../${var.key_name}.pem")

    # Retry configuration
    timeout     = "5m"
  }

  # Aguardar instância estar pronta
  provisioner "remote-exec" {
    inline = [
      "echo '⏳ Aguardando instância DB estar pronta...'",
      "while [ ! -d /opt/solarway ]; do sleep 5; done",
      "echo '✅ Instância pronta!'"
    ]
  }

  # Criar diretórios
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /opt/solarway/services/db",
      "mkdir -p /opt/solarway/services/db/mysql-init"
    ]
  }

  # Enviar .env
  provisioner "file" {
    content     = templatefile("${path.module}/templates/env.db.tmpl", {
      db_password         = var.db_password
      redis_password      = var.redis_password
      github_username     = var.github_username
      github_access_token = var.github_token
    })
    destination = "/opt/solarway/services/db/.env"
  }

  # Enviar docker-compose
  provisioner "file" {
    source      = "../../../services/db/docker-compose.yml"
    destination = "/opt/solarway/services/db/docker-compose.yml"
  }

  # Enviar scripts de inicialização do MySQL (se existirem)
  provisioner "file" {
    source      = "../../../services/db/mysql-init/"
    destination = "/opt/solarway/services/db/mysql-init/"
  }

  # Executar setup
  provisioner "remote-exec" {
    inline = [
      "cd /opt/solarway/services/db",
      "echo '${var.github_token}' | sudo docker login ghcr.io -u '${var.github_username}' --password-stdin || true",
      "sudo docker compose pull",
      "sudo docker compose up -d",
      "sleep 30",
      "echo '⏳ Aguardando MySQL iniciar...'",
      "until nc -z localhost 3306; do sleep 5; done",
      "echo '✅ Database deploy concluído!'"
    ]
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPLOY: BACKEND MONOLITH
# ═══════════════════════════════════════════════════════════════════════════════
resource "null_resource" "deploy_backend_1" {
  depends_on = [null_resource.deploy_db]

  triggers = {
    instance_id = module.ec2_backend_1.instance_id
  }

  connection {
    type                = "ssh"
    user                = "ubuntu"
    private_key         = file("${path.module}/../../../${var.key_name}.pem")
    host                = module.ec2_backend_1.private_ip
    bastion_host        = module.ec2_nginx.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("${path.module}/../../../${var.key_name}.pem")
    timeout             = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '⏳ Aguardando instância Backend-1...'",
      "while [ ! -d /opt/solarway ]; do sleep 5; done",
      "mkdir -p /opt/solarway/services/backend/monolith",
      "echo '✅ Instância pronta!'"
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/env.backend.tmpl", {
      db_private_ip       = module.ec2_db.private_ip
      db_password         = var.db_password
      bucket_name         = var.bucket_name
      email               = var.email
      email_password      = var.email_password
      bot_secret          = var.bot_secret
      github_username     = var.github_username
      github_access_token = var.github_token
    })
    destination = "/opt/solarway/services/backend/monolith/.env"
  }

  provisioner "file" {
    source      = "../../../services/backend/monolith/"
    destination = "/opt/solarway/services/backend/monolith/"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /opt/solarway/services/backend/monolith",
      "echo '${var.github_token}' | sudo docker login ghcr.io -u '${var.github_username}' --password-stdin || true",
      "sudo docker compose pull",
      "sudo docker compose up -d",
      "sleep 20",
      "echo '✅ Backend Monolith deploy concluído!'"
    ]
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPLOY: BACKEND MICROSERVICE
# ═══════════════════════════════════════════════════════════════════════════════
resource "null_resource" "deploy_backend_2" {
  depends_on = [null_resource.deploy_db]

  triggers = {
    instance_id = module.ec2_backend_2.instance_id
  }

  connection {
    type                = "ssh"
    user                = "ubuntu"
    private_key         = file("${path.module}/../../../${var.key_name}.pem")
    host                = module.ec2_backend_2.private_ip
    bastion_host        = module.ec2_nginx.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("${path.module}/../../../${var.key_name}.pem")
    timeout             = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '⏳ Aguardando instância Backend-2...'",
      "while [ ! -d /opt/solarway ]; do sleep 5; done",
      "mkdir -p /opt/solarway/services/backend/microservice",
      "echo '✅ Instância pronta!'"
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/env.backend.tmpl", {
      db_private_ip       = module.ec2_db.private_ip
      db_password         = var.db_password
      bucket_name         = var.bucket_name
      email               = var.email
      email_password      = var.email_password
      bot_secret          = var.bot_secret
      github_username     = var.github_username
      github_access_token = var.github_token
    })
    destination = "/opt/solarway/services/backend/microservice/.env"
  }

  provisioner "file" {
    source      = "../../../services/backend/microservice/"
    destination = "/opt/solarway/services/backend/microservice/"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /opt/solarway/services/backend/microservice",
      "echo '${var.github_token}' | sudo docker login ghcr.io -u '${var.github_username}' --password-stdin || true",
      "sudo docker compose pull",
      "sudo docker compose up -d",
      "sleep 20",
      "echo '✅ Backend Microservice deploy concluído!'"
    ]
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPLOY: FRONTEND INSTITUCIONAL
# ═══════════════════════════════════════════════════════════════════════════════
resource "null_resource" "deploy_frontend_1" {
  depends_on = [null_resource.deploy_backend_1]

  triggers = {
    instance_id = module.ec2_frontend_1.instance_id
  }

  connection {
    type                = "ssh"
    user                = "ubuntu"
    private_key         = file("${path.module}/../../../${var.key_name}.pem")
    host                = module.ec2_frontend_1.private_ip
    bastion_host        = module.ec2_nginx.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("${path.module}/../../../${var.key_name}.pem")
    timeout             = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '⏳ Aguardando instância Frontend-1...'",
      "while [ ! -d /opt/solarway ]; do sleep 5; done",
      "mkdir -p /opt/solarway/services/frontend/institucional-website",
      "echo '✅ Instância pronta!'"
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/env.frontend.tmpl", {
      backend_1_ip = module.ec2_backend_1.private_ip
    })
    destination = "/opt/solarway/services/frontend/institucional-website/.env"
  }

  provisioner "file" {
    source      = "../../../services/frontend/institucional-website/"
    destination = "/opt/solarway/services/frontend/institucional-website/"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /opt/solarway/services/frontend/institucional-website",
      "echo '${var.github_token}' | sudo docker login ghcr.io -u '${var.github_username}' --password-stdin || true",
      "sudo docker compose pull",
      "sudo docker compose up -d",
      "sleep 10",
      "echo '✅ Frontend Institucional deploy concluído!'"
    ]
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPLOY: FRONTEND MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════
resource "null_resource" "deploy_frontend_2" {
  depends_on = [null_resource.deploy_backend_1]

  triggers = {
    instance_id = module.ec2_frontend_2.instance_id
  }

  connection {
    type                = "ssh"
    user                = "ubuntu"
    private_key         = file("${path.module}/../../../${var.key_name}.pem")
    host                = module.ec2_frontend_2.private_ip
    bastion_host        = module.ec2_nginx.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("${path.module}/../../../${var.key_name}.pem")
    timeout             = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '⏳ Aguardando instância Frontend-2...'",
      "while [ ! -d /opt/solarway ]; do sleep 5; done",
      "mkdir -p /opt/solarway/services/frontend/management-system",
      "echo '✅ Instância pronta!'"
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/env.frontend.tmpl", {
      backend_1_ip = module.ec2_backend_1.private_ip
    })
    destination = "/opt/solarway/services/frontend/management-system/.env"
  }

  provisioner "file" {
    source      = "../../../services/frontend/management-system/"
    destination = "/opt/solarway/services/frontend/management-system/"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /opt/solarway/services/frontend/management-system",
      "echo '${var.github_token}' | sudo docker login ghcr.io -u '${var.github_username}' --password-stdin || true",
      "sudo docker compose pull",
      "sudo docker compose up -d",
      "sleep 10",
      "echo '✅ Frontend Management deploy concluído!'"
    ]
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPLOY: PROXY NGINX (ÚLTIMO - com todos os IPs conhecidos)
# ═══════════════════════════════════════════════════════════════════════════════
resource "null_resource" "deploy_nginx" {
  depends_on = [
    null_resource.deploy_backend_1,
    null_resource.deploy_backend_2,
    null_resource.deploy_frontend_1,
    null_resource.deploy_frontend_2
  ]

  triggers = {
    nginx_id         = module.ec2_nginx.instance_id
    backend_1_ip     = module.ec2_backend_1.private_ip
    backend_2_ip     = module.ec2_backend_2.private_ip
    frontend_1_ip    = module.ec2_frontend_1.private_ip
    frontend_2_ip    = module.ec2_frontend_2.private_ip
    nginx_conf_hash  = filemd5("../../../services/proxy/nginx.conf.template")
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/../../../${var.key_name}.pem")
    host        = module.ec2_nginx.public_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '⏳ Aguardando instância Proxy...'",
      "while [ ! -d /opt/solarway ]; do sleep 5; done",
      "mkdir -p /opt/solarway/services/proxy",
      "echo '✅ Instância pronta!'"
    ]
  }

  # Enviar template do nginx
  provisioner "file" {
    source      = "../../../services/proxy/nginx.conf.template"
    destination = "/opt/solarway/services/proxy/nginx.conf.template"
  }

  # Enviar docker-compose do proxy
  provisioner "file" {
    source      = "../../../services/proxy/docker-compose.yml"
    destination = "/opt/solarway/services/proxy/docker-compose.yml"
  }

  # Configurar e iniciar
  provisioner "remote-exec" {
    inline = [
      "cd /opt/solarway/services/proxy",
      # Gerar nginx.conf com IPs
      "export BACKEND_PRIVATE_IP=${module.ec2_backend_1.private_ip}",
      "export MANAGEMENT_PRIVATE_IP=${module.ec2_frontend_2.private_ip}",
      "export INSTITUCIONAL_PRIVATE_IP=${module.ec2_frontend_1.private_ip}",
      "envsubst < nginx.conf.template > nginx.conf",
      # Criar .env para docker-compose
      "echo 'PORT_PROXY=80' > .env",
      "echo 'PORT_PROXY_INSTITUCIONAL=81' >> .env",
      # Iniciar
      "sudo docker compose up -d",
      "sleep 5",
      "curl -sf http://localhost/health && echo '✅ Proxy healthcheck OK' || echo '⚠️  Verifique o proxy manualmente'"
    ]
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "proxy_public_ip" {
  description = "IP Público do Proxy"
  value       = module.ec2_nginx.public_ip
}

output "proxy_url" {
  description = "URL de acesso"
  value       = "http://${module.ec2_nginx.public_ip}"
}

output "ssh_bastion" {
  description = "Comando SSH via bastion"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${module.ec2_nginx.public_ip}"
}
```

---

## 6. Docker Compose Ajustados

### 6.1 Proxy (`services/proxy/docker-compose.yml`)

```yaml
services:
  nginx-proxy:
    image: nginx:alpine
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "81:81"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    networks:
      - solarway_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  solarway_network:
    name: solarway_network
    external: true
```

### 6.2 Database (`services/db/docker-compose.yml`)

```yaml
version: "3.8"

services:
  redis:
    image: redis:7.4
    container_name: redis-multidb
    ports:
      - "6379:6379"
    command: >
      redis-server
      --databases 3
      --save ""
      --appendonly no
      --maxmemory-policy allkeys-lru
      --requirepass ${REDIS_PASSWORD:-redis123}
    restart: unless-stopped
    networks:
      - storage_network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-redis123}", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  mysql:
    image: mysql:8.0
    container_name: mysql-db
    command: >
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --default-authentication-plugin=mysql_native_password
      --log-bin-trust-function-creators=1
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-root123}
      MYSQL_DATABASE: solarway
      MYSQL_USER: ${MYSQL_USER:-solarway}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-solarway123}
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./mysql-init:/docker-entrypoint-initdb.d
    restart: unless-stopped
    networks:
      - storage_network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD:-root123}"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  mysql_data:

networks:
  storage_network:
    name: storage_network
    driver: bridge
```

### 6.3 Backend Monolith (`services/backend/monolith/docker-compose.yml`)

```yaml
version: "3.8"

services:
  backend-service:
    image: ghcr.io/projeto-de-extensao-grupo-06/springboot-web-backend:latest
    platform: linux/amd64
    container_name: backend-monolith
    environment:
      SPRING_PROFILES_ACTIVE: prod
      SPRING_DATASOURCE_URL: jdbc:mysql://${DB_HOST:-mysql-db}:3306/solarway?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
      SPRING_DATASOURCE_USERNAME: ${DB_USERNAME:-solarway}
      SPRING_DATASOURCE_PASSWORD: ${DB_PASSWORD}
      SPRING_JPA_HIBERNATE_DDL_AUTO: update
      SPRING_DATA_REDIS_HOST: ${REDIS_HOST:-redis-multidb}
      SPRING_DATA_REDIS_PORT: 6379
      SPRING_DATA_REDIS_PASSWORD: ${REDIS_PASSWORD}
      EMAIL: "${EMAIL}"
      PASSWORD_EMAIL: "${PASSWORD_EMAIL}"
      SERVER_PORT: 8000
      BOT_SECRET: "${BOT_SECRET}"
      SOLARIZE_SECURITY_BOT_SECRET: "${BOT_SECRET}"
      BUCKET_NAME: "${BUCKET_NAME}"
      AWS_ACCESS_KEY_ID: "${AWS_ACCESS_KEY_ID}"
      AWS_SECRET_ACCESS_KEY: "${AWS_SECRET_ACCESS_KEY}"
      AWS_SESSION_TOKEN: "${AWS_SESSION_TOKEN}"
    ports:
      - "8000:8000"
    restart: unless-stopped
    networks:
      - solarway_network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8000/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  solarway_network:
    name: solarway_network
    driver: bridge
```

---

## 7. Script de Deploy Automatizado

### 7.1 PowerShell (`scripts/deploy/deploy-prod.ps1`)

```powershell
<#
.SYNOPSIS
    Script de deploy automatizado para ambiente de produção Solarway
.DESCRIPTION
    Executa terraform apply com validações prévias e healthchecks
.NOTES
    Requer: AWS CLI, Terraform >= 1.0, SSH Key
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$KeyName = "solarway",

    [Parameter(Mandatory=$false)]
    [switch]$Destroy,

    [Parameter(Mandatory=$false)]
    [switch]$SkipApproval
)

$ErrorActionPreference = "Stop"
$env:TF_IN_AUTOMATION = "true"

# Cores para output
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Reset = "`e[0m"

function Write-Status {
    param($Message, $Type = "Info")
    $prefix = switch ($Type) {
        "Success" { "${Green}✅" }
        "Warning" { "${Yellow}⚠️" }
        "Error"   { "${Red}❌" }
        default   { "➡️" }
    }
    Write-Host "$prefix $Message${Reset}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# VALIDAÇÕES PRÉ-DEPLOY
# ═══════════════════════════════════════════════════════════════════════════════

Write-Status "Iniciando validações pré-deploy..."

# Verificar se está no diretório correto
if (-not (Test-Path "terraform/environments/prod")) {
    Write-Status "Execute este script da raiz do projeto" "Error"
    exit 1
}

# Verificar AWS credentials
try {
    $awsIdentity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
    Write-Status "AWS autenticado: $($awsIdentity.Arn)" "Success"
} catch {
    Write-Status "Credenciais AWS não encontradas. Execute 'aws configure'" "Error"
    exit 1
}

# Verificar SSH Key
$keyPath = "./${KeyName}.pem"
if (-not (Test-Path $keyPath)) {
    Write-Status "Chave SSH não encontrada: $keyPath" "Error"
    Write-Status "Verifique se a chave existe ou especifique -KeyName" "Warning"
    exit 1
}

# Permissões da chave (Linux/Mac via WSL)
if ($IsLinux -or $IsMacOS -or $env:WSL_DISTRO_NAME) {
    chmod 600 $keyPath
}

# Verificar Terraform
$tfVersion = terraform version -json | ConvertFrom-Json
Write-Status "Terraform versão: $($tfVersion.terraform_version)" "Success"

# Verificar variáveis de ambiente necessárias
$requiredVars = @(
    "TF_VAR_db_password",
    "TF_VAR_github_token",
    "TF_VAR_github_username"
)

$missingVars = $requiredVars | Where-Object { -not [Environment]::GetEnvironmentVariable($_) }
if ($missingVars) {
    Write-Status "Variáveis de ambiente ausentes:" "Error"
    $missingVars | ForEach-Object { Write-Host "  - $_" }
    Write-Status "Exemplo de configuração:" "Warning"
    Write-Host @"
    `$env:TF_VAR_db_password = "senha_segura"
    `$env:TF_VAR_github_token = "ghp_xxxx"
    `$env:TF_VAR_github_username = "usuario"
"@
    exit 1
}

Write-Status "Todas as validações passaram!" "Success"

# ═══════════════════════════════════════════════════════════════════════════════
# EXECUÇÃO TERRAFORM
# ═══════════════════════════════════════════════════════════════════════════════

Set-Location "terraform/environments/prod"

if ($Destroy) {
    Write-Status "Modo DESTROY ativado - Isso removerá TODA a infraestrutura!" "Warning"
    if (-not $SkipApproval) {
        $confirmation = Read-Host "Digite 'DESTROY' para confirmar"
        if ($confirmation -ne "DESTROY") {
            Write-Status "Operação cancelada" "Warning"
            exit 0
        }
    }
    terraform destroy -auto-approve
    exit 0
}

# Init
Write-Status "Executando terraform init..."
terraform init -upgrade

# Plan
Write-Status "Executando terraform plan..."
$planFile = "tfplan"
terraform plan -out=$planFile

if ($LASTEXITCODE -ne 0) {
    Write-Status "Terraform plan falhou" "Error"
    exit 1
}

# Aprovação
if (-not $SkipApproval) {
    $confirmation = Read-Host "Deseja aplicar as mudanças? (s/N)"
    if ($confirmation -ne "s" -and $confirmation -ne "S") {
        Write-Status "Operação cancelada pelo usuário" "Warning"
        exit 0
    }
}

# Apply
Write-Status "Executando terraform apply (isso pode levar 10-15 minutos)..."
terraform apply -auto-approve $planFile

if ($LASTEXITCODE -ne 0) {
    Write-Status "Terraform apply falhou" "Error"
    exit 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# PÓS-DEPLOY: HEALTHCHECKS
# ═══════════════════════════════════════════════════════════════════════════════

Write-Status "Aguardando serviços inicializarem..."
Start-Sleep -Seconds 30

$proxyIp = terraform output -raw proxy_public_ip

Write-Status "Verificando Proxy..."
try {
    $response = Invoke-WebRequest -Uri "http://${proxyIp}/health" -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Status "Proxy healthcheck OK" "Success"
    }
} catch {
    Write-Status "Proxy não respondeu ao healthcheck" "Warning"
}

Write-Status ""
Write-Status "═══════════════════════════════════════════════════" "Success"
Write-Status "DEPLOY CONCLUÍDO COM SUCESSO!" "Success"
Write-Status "═══════════════════════════════════════════════════" "Success"
Write-Status ""
Write-Status "URL de acesso: http://${proxyIp}"
Write-Status "SSH Bastion: ssh -i ${KeyName}.pem ubuntu@${proxyIp}"
Write-Status ""
Write-Status "Para acessar instâncias privadas via bastion:"
Write-Status "  ssh -i ${KeyName}.pem -J ubuntu@${proxyIp} ubuntu@<ip-privado>"
Write-Status ""

Set-Location "../../.."
```

### 7.2 Bash Equivalente (`scripts/deploy/deploy-prod.sh`)

```bash
#!/bin/bash
# ==============================================================================
# Script de deploy automatizado para produção (Linux/Mac/WSL)
# ==============================================================================

set -e

KEY_NAME="${1:-solarway}"
KEY_PATH="./${KEY_NAME}.pem"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}✅${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
error() { echo -e "${RED}❌${NC} $1"; }

# Validações
if [ ! -d "terraform/environments/prod" ]; then
    error "Execute da raiz do projeto"
    exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
    error "Chave SSH não encontrada: $KEY_PATH"
    exit 1
fi

chmod 600 "$KEY_PATH"

# Verificar AWS
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    error "Credenciais AWS inválidas"
    exit 1
fi

log "Iniciando deploy..."

cd terraform/environments/prod

# Terraform
terraform init -upgrade
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

PROXY_IP=$(terraform output -raw proxy_public_ip)

log "Aguardando serviços..."
sleep 30

# Healthcheck
if curl -sf "http://${PROXY_IP}/health" > /dev/null; then
    log "Proxy healthcheck OK"
else
    warn "Proxy não respondeu ao healthcheck"
fi

log "═══════════════════════════════════════════════════"
log "DEPLOY CONCLUÍDO!"
log "═══════════════════════════════════════════════════"
log "URL: http://${PROXY_IP}"
log "SSH: ssh -i ${KEY_PATH} ubuntu@${PROXY_IP}"

cd ../../..
```

---

## 8. Templates de Environment

### 8.1 Database (`terraform/environments/prod/templates/env.db.tmpl`)

```bash
# MySQL
MYSQL_ROOT_PASSWORD=${db_password}
MYSQL_DATABASE=solarway
MYSQL_USER=solarway
MYSQL_PASSWORD=${db_password}

# Redis
REDIS_PASSWORD=${redis_password}

# GitHub Container Registry
GITHUB_USERNAME=${github_username}
GITHUB_ACCESS_TOKEN=${github_access_token}
```

### 8.2 Backend (`terraform/environments/prod/templates/env.backend.tmpl`)

```bash
# Database
DB_HOST=${db_private_ip}
DB_USERNAME=solarway
DB_PASSWORD=${db_password}
REDIS_HOST=${db_private_ip}
REDIS_PASSWORD=${redis_password}

# Spring
SPRING_PROFILES_ACTIVE=prod
SPRING_DATASOURCE_URL=jdbc:mysql://${db_private_ip}:3306/solarway?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
SPRING_DATASOURCE_USERNAME=solarway
SPRING_DATASOURCE_PASSWORD=${db_password}
SPRING_JPA_HIBERNATE_DDL_AUTO=update
SPRING_DATA_REDIS_HOST=${db_private_ip}
SPRING_DATA_REDIS_PORT=6379

# Application
SERVER_PORT=8000
BOT_SECRET=${bot_secret}
SOLARIZE_SECURITY_BOT_SECRET=${bot_secret}
BUCKET_NAME=${bucket_name}
EMAIL=${email}
PASSWORD_EMAIL=${email_password}

# AWS (via IAM Instance Profile, opcional)
AWS_ACCESS_KEY_ID=${github_access_token}
AWS_SECRET_ACCESS_KEY=${github_access_token}
AWS_SESSION_TOKEN=

# GitHub
GITHUB_USERNAME=${github_username}
GITHUB_ACCESS_TOKEN=${github_access_token}
```

### 8.3 Frontend (`terraform/environments/prod/templates/env.frontend.tmpl`)

```bash
# API Backend
BACKEND_URL=http://${backend_1_ip}:8000
VITE_API_URL=http://${backend_1_ip}:8000/api
```

---

## 9. Fluxo de Deploy

### 9.1 Ordem de Execução

```
1. VPC + Security Groups
   └── Aguardar criação

2. Proxy (Público)
   └── User Data: Instalar Docker, configurar NAT
   └── Aguardar healthcheck

3. Database (Privado)
   └── Depende: Proxy (NAT route)
   └── Deploy: Docker Compose com MySQL + Redis
   └── Healthcheck: Portas 3306 e 6379

4. Backend Monolith (Privado)
   └── Depende: Database
   └── Deploy: Docker Compose
   └── Healthcheck: Porta 8000

5. Backend Microservice (Privado)
   └── Depende: Database
   └── Deploy: Docker Compose
   └── Healthcheck: Porta 8082

6. Frontend Institucional (Privado)
   └── Depende: Backend Monolith
   └── Deploy: Docker Compose
   └── Healthcheck: Porta 8081

7. Frontend Management (Privado)
   └── Depende: Backend Monolith
   └── Deploy: Docker Compose
   └── Healthcheck: Porta 8080

8. Bots (Privado)
   └── Depende: Database
   └── Deploy: Docker Compose

9. Proxy Configuração Final
   └── Depende: Todas as instâncias
   └── Deploy: nginx.conf com IPs privados
   └── Reload: nginx
```

### 9.2 Comandos Úteis

```bash
# Ver status do deploy
terraform show

# Ver logs de uma instância específica
ssh -i solarway.pem ubuntu@<proxy-ip> \
  'ssh ubuntu@<private-ip> "tail -f /var/log/solarway-*.log"'

# Restart de serviço
ssh -i solarway.pem -J ubuntu@<proxy-ip> ubuntu@<private-ip> \
  'sudo docker compose -f /opt/solarway/services/backend/monolith/docker-compose.yml restart'

# Ver containers rodando
ssh -i solarway.pem -J ubuntu@<proxy-ip> ubuntu@<private-ip> \
  'sudo docker ps'
```

---

## 10. Troubleshooting

### 10.1 Problemas Comuns

| Problema | Causa | Solução |
|----------|-------|---------|
| `docker pull` falha | Sem internet na privada | Verificar NAT no proxy: `sudo iptables -t nat -L` |
| Network não encontrada | Docker network não criada | Criar manualmente: `docker network create solarway_network` |
| SSH timeout | Bastion não responde | Verificar SG do proxy: porta 22 aberta? |
| Backend não conecta DB | IP errado no .env | Verificar template: `${db_private_ip}` resolvido? |
| 502 Bad Gateway | Backend não rodando | Verificar: `docker ps` e logs do container |
| Terraform lock | Deploy anterior travou | `terraform force-unlock <lock-id>` |

### 10.2 Comandos de Debug

```bash
# Verificar NAT no proxy
sudo sysctl net.ipv4.ip_forward
sudo iptables -t nat -L -n -v

# Verificar conectividade da privada
curl -I https://registry-1.docker.io

# Verificar logs do user data
sudo tail -f /var/log/cloud-init-output.log
sudo tail -f /var/log/solarway-*.log

# Verificar configuração do nginx
cat /opt/solarway/services/proxy/nginx.conf
sudo docker exec nginx-proxy nginx -t

# Restart limpo
sudo docker compose down
sudo docker system prune -f
sudo docker compose up -d
```

---

## 11. Checklist de Deploy

Antes de executar o deploy:

- [ ] Chave SSH `solarway.pem` existe na raiz
- [ ] Credenciais AWS configuradas (`aws configure`)
- [ ] Variáveis de ambiente definidas:
  - [ ] `TF_VAR_db_password`
  - [ ] `TF_VAR_redis_password`
  - [ ] `TF_VAR_github_token`
  - [ ] `TF_VAR_github_username`
  - [ ] `TF_VAR_bot_secret`
  - [ ] `TF_VAR_email`
  - [ ] `TF_VAR_email_password`
- [ ] Terraform >= 1.0 instalado
- [ ] Docker Hub / GHCR acessível (token válido)

---

**Versão:** 1.0
**Última atualização:** 2026-04-01
**Autor:** Solarway DevOps Team
