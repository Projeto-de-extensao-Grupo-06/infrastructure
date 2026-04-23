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

variable "use_nat_gateway" {
  description = "Se true, usa NAT Gateway (pago). Se false, usa Nginx como NAT Instance (grátis)."
  type        = bool
  default     = false
}

module "vpc_prod" {
  source = "../../modules/vpc"

  environment = "prod"
  vpc_cidr    = "10.0.0.0/24"

  # Subnet Pública
  public_subnets = ["10.0.0.0/28"]

  # Subnets Privadas
  private_subnets = [
    "10.0.0.16/28",
    "10.0.0.32/28",
    "10.0.0.48/28",
    "10.0.0.64/28"
  ]

  azs = ["us-east-1a", "us-east-1a", "us-east-1a", "us-east-1a", "us-east-1a"]

  enable_nat_gateway = var.use_nat_gateway
}

module "ec2_nginx" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "nginx-proxy"
  instance_type        = "t3.small"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.public_subnet_ids[0]
  frontend_ports       = [80, 443]
  iam_instance_profile = "LabInstanceProfile"
  source_dest_check    = false

  user_data = <<-EOT
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive
    mkdir -p /tmp/solarway/services/proxy
    mkdir -p /tmp/solarway/scripts/setup/prod

    # Docker config
    base64 -d << 'EOF' > /tmp/solarway/services/proxy/docker-compose.yml
    ${base64encode(file("../../../services/proxy/docker-compose.yml"))}
    EOF

    cat << 'EOF' > /tmp/solarway/services/proxy/nginx.conf.template
    ${file("../../../services/proxy/nginx.conf.template")}
    EOF

    # Runtime Env
    cat << EOF > /tmp/solarway/.env
    BACKEND_PRIVATE_IP=${module.ec2_backend_1.private_ip}
    MANAGEMENT_PRIVATE_IP=${module.ec2_frontend_2.private_ip}
    INSTITUCIONAL_PRIVATE_IP=${module.ec2_frontend_1.private_ip}
    N8N_PRIVATE_IP=${module.ec2_chatbot.private_ip}
    WAHA_PRIVATE_IP=${module.ec2_chatbot.private_ip}
    DOMAIN=${var.domain}
    EMAIL=${var.email}
    GITHUB_USERNAME=${var.github_username}
    GITHUB_ACCESS_TOKEN=${var.github_token}
    EOF


    # Scripts
    cat << 'EOF' > /tmp/solarway/scripts/setup/setup-vm.sh
    ${file("../../../scripts/setup-vm.sh")}
    EOF

    cat << 'EOF' > /tmp/solarway/scripts/setup/prod/setup-proxy.sh
    ${file("./scripts/setup-proxy.sh")}
    EOF

    find /tmp/solarway -type f -name "*.sh" -exec sed -i 's/\r$//' {} +
    chmod +x /tmp/solarway/scripts/setup/setup-vm.sh /tmp/solarway/scripts/setup/prod/setup-proxy.sh
    
    sudo bash /tmp/solarway/scripts/setup/prod/setup-proxy.sh
  EOT
}

resource "aws_route" "private_nat_access" {
  count                  = var.use_nat_gateway ? 0 : 1
  route_table_id         = module.vpc_prod.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.ec2_nginx.primary_network_interface_id
}

resource "aws_security_group_rule" "proxy_nat_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks              = ["10.0.0.0/24"]
  security_group_id        = module.ec2_nginx.security_group_id
  description              = "Allow traffic from private subnets for NAT routing"
}

module "ec2_frontend_1" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "frontend-1"
  instance_type        = "t3.small"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[0]
  frontend_ports       = [8081] # Apenas Institucional Website
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    export FRONTEND_TYPE="institutional"
    bash /tmp/setup-vm.sh
  EOT
}

module "ec2_frontend_2" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "frontend-2"
  instance_type        = "t3.small"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[0]
  frontend_ports       = [8080] # Apenas Management System
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    export FRONTEND_TYPE="management"
    bash /tmp/setup-vm.sh
  EOT
}

module "ec2_backend_1" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "backend-1"
  instance_type        = "t3.medium"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[1]
  frontend_ports       = [8000] # Apenas Monolito
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    sed -i 's/\r$//' /tmp/setup-vm.sh
    export BACKEND_TYPE="monolith"
    sed -i 's/\r$//' /tmp/setup-vm.sh
    bash /tmp/setup-vm.sh
  EOT
}

module "ec2_backend_2" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "backend-2"
  instance_type        = "t3.medium"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[1]
  frontend_ports       = [8082] # Apenas Microserviço
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    sed -i 's/\r$//' /tmp/setup-vm.sh
    export BACKEND_TYPE="microservice"
    sed -i 's/\r$//' /tmp/setup-vm.sh
    bash /tmp/setup-vm.sh
  EOT
}

module "ec2_chatbot" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "chatbot"
  instance_type        = "t3.small"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[3]
  frontend_ports       = [3000, 5678]
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    export BOT_TYPE="chatbot"
    sed -i 's/\r$//' /tmp/setup-vm.sh
    bash /tmp/setup-vm.sh
  EOT
}

module "ec2_webscraping" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "webscraping"
  instance_type        = "t3.micro"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[3]
  frontend_ports       = [5000]
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    export BOT_TYPE="webscraping"
    sed -i 's/\r$//' /tmp/setup-vm.sh
    bash /tmp/setup-vm.sh
  EOT
}

module "ec2_db" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "database"
  instance_type        = "t3.large"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[2]
  frontend_ports       = [3306, 6379]
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    sed -i 's/\r$//' /tmp/setup-vm.sh
    sed -i 's/\r$//' /tmp/setup-vm.sh
    bash /tmp/setup-vm.sh
  EOT
}

# ── Outputs: Acesso e IPs de todas as instâncias ──────────────────────────────

output "nginx_public_ip" {
  description = "IP Público do Nginx Proxy (único ponto de entrada externo)"
  value       = module.ec2_nginx.public_ip
}

output "nginx_ssm_connect" {
  description = "SSM — Nginx Proxy"
  value       = "aws ssm start-session --target ${module.ec2_nginx.instance_id}"
}

output "nginx_logs" {
  description = "Logs — Nginx Proxy"
  value       = "aws ssm start-session --target ${module.ec2_nginx.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "backend_1_private_ip" {
  description = "IP Privado — Backend Monolito"
  value       = module.ec2_backend_1.private_ip
}

output "backend_1_ssm_connect" {
  description = "SSM — Backend Monolito"
  value       = "aws ssm start-session --target ${module.ec2_backend_1.instance_id}"
}

output "backend_1_logs" {
  description = "Logs — Backend Monolito"
  value       = "aws ssm start-session --target ${module.ec2_backend_1.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "backend_2_private_ip" {
  description = "IP Privado — Backend Microserviço"
  value       = module.ec2_backend_2.private_ip
}

output "backend_2_ssm_connect" {
  description = "SSM — Backend Microserviço"
  value       = "aws ssm start-session --target ${module.ec2_backend_2.instance_id}"
}

output "backend_2_logs" {
  description = "Logs — Backend Microserviço"
  value       = "aws ssm start-session --target ${module.ec2_backend_2.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "frontend_1_private_ip" {
  description = "IP Privado — Frontend Institucional"
  value       = module.ec2_frontend_1.private_ip
}

output "frontend_1_ssm_connect" {
  description = "SSM — Frontend Institucional"
  value       = "aws ssm start-session --target ${module.ec2_frontend_1.instance_id}"
}

output "frontend_1_logs" {
  description = "Logs — Frontend Institucional"
  value       = "aws ssm start-session --target ${module.ec2_frontend_1.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "frontend_2_private_ip" {
  description = "IP Privado — Frontend Management"
  value       = module.ec2_frontend_2.private_ip
}

output "frontend_2_ssm_connect" {
  description = "SSM — Frontend Management"
  value       = "aws ssm start-session --target ${module.ec2_frontend_2.instance_id}"
}

output "frontend_2_logs" {
  description = "Logs — Frontend Management"
  value       = "aws ssm start-session --target ${module.ec2_frontend_2.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "chatbot_private_ip" {
  description = "IP Privado — Chatbot (n8n + WAHA)"
  value       = module.ec2_chatbot.private_ip
}

output "chatbot_ssm_connect" {
  description = "SSM — Chatbot"
  value       = "aws ssm start-session --target ${module.ec2_chatbot.instance_id}"
}

output "chatbot_logs" {
  description = "Logs — Chatbot"
  value       = "aws ssm start-session --target ${module.ec2_chatbot.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "webscraping_private_ip" {
  description = "IP Privado — Web Scraping"
  value       = module.ec2_webscraping.private_ip
}

output "webscraping_ssm_connect" {
  description = "SSM — Web Scraping"
  value       = "aws ssm start-session --target ${module.ec2_webscraping.instance_id}"
}

output "webscraping_logs" {
  description = "Logs — Web Scraping"
  value       = "aws ssm start-session --target ${module.ec2_webscraping.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "db_private_ip" {
  description = "IP Privado — Banco de Dados (MySQL + Redis)"
  value       = module.ec2_db.private_ip
}

output "db_ssm_connect" {
  description = "SSM — Banco de Dados"
  value       = "aws ssm start-session --target ${module.ec2_db.instance_id}"
}

output "db_logs" {
  description = "Logs — Banco de Dados"
  value       = "aws ssm start-session --target ${module.ec2_db.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}



module "s3_raw" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarway-datalake-raw"
}

module "s3_trusted" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarway-datalake-trusted"
}

module "s3_refined" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarway-datalake-refined"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc_prod.vpc_id
  service_name = "com.amazonaws.us-east-1.s3"

  route_table_ids = [
    module.vpc_prod.public_route_table_id,
    module.vpc_prod.private_route_table_id
  ]

  tags = {
    Name = "solarway-s3-endpoint"
    Environment = "prod"
  }
}
