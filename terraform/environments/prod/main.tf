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

module "vpc_prod" {
  source = "../../modules/vpc"

  environment = "prod"
  vpc_cidr    = "10.0.0.0/16"

  public_subnets = ["10.0.1.0/24", "10.0.4.0/24"]
  private_subnets = [
    "10.0.2.0/24", # A (Frontend)
    "10.0.3.0/24", # B (Backend)
    "10.0.5.0/24", # C (Chatbot/Webscraping)
    "10.0.6.0/24"  # D (Banco de Dados) 
  ]
  azs = ["us-east-1a", "us-east-1b", "us-east-1a", "us-east-1b", "us-east-1a", "us-east-1b"]
}

module "ec2_nginx" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "nginx-proxy"
  instance_type  = "t3.small"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.public_subnet_ids[0]
  key_name       = var.key_name
  frontend_ports = [22, 80, 443]
  user_data      = "${file("../../../scripts/setup/setup-vm.sh")}\n${file("../../../scripts/setup/prod/setup-proxy.sh")}"
}

module "ec2_frontend_1" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "frontend-1"
  instance_type  = "t3.small"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[0]
  frontend_ports = [22, 8081] # Apenas Institucional Website
  allowed_cidr_blocks = ["10.0.0.0/16"]
  user_data      = "${file("../../../scripts/setup/setup-vm.sh")}\n${replace(file("../../../scripts/setup/prod/setup-frontend.sh"), "#!/bin/bash", "export FRONTEND_TYPE=\"institutional\"")}"
}

module "ec2_frontend_2" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "frontend-2"
  instance_type  = "t3.small"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[0]
  frontend_ports = [22, 8080] # Apenas Management System
  allowed_cidr_blocks = ["10.0.0.0/16"]
  user_data      = "${file("../../../scripts/setup/setup-vm.sh")}\n${replace(file("../../../scripts/setup/prod/setup-frontend.sh"), "#!/bin/bash", "export FRONTEND_TYPE=\"management\"")}"
}

module "ec2_backend_1" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "backend-1"
  instance_type  = "t3.medium"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[1]
  frontend_ports = [22, 8000] # Apenas Monolito
  allowed_cidr_blocks = ["10.0.0.0/16"]
  user_data      = "${file("../../../scripts/setup/setup-vm.sh")}\n${replace(file("../../../scripts/setup/prod/setup-backend.sh"), "#!/bin/bash", "export BACKEND_TYPE=\"monolith\"")}"
}

module "ec2_backend_2" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "backend-2"
  instance_type  = "t3.medium"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[1]
  frontend_ports = [22, 8082] # Apenas Microserviço
  allowed_cidr_blocks = ["10.0.0.0/16"]
  user_data      = "${file("../../../scripts/setup/setup-vm.sh")}\n${replace(file("../../../scripts/setup/prod/setup-backend.sh"), "#!/bin/bash", "export BACKEND_TYPE=\"microservice\"")}"
}

module "ec2_chatbot" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "chatbot"
  instance_type  = "t3.small"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[2]
  frontend_ports = [22, 3000, 5678]
  allowed_cidr_blocks = ["10.0.0.0/16"]
  user_data      = "${file("../../../scripts/setup/setup-vm.sh")}\n${replace(file("../../../scripts/setup/prod/setup-bot.sh"), "#!/bin/bash", "export BOT_TYPE=\"chatbot\"")}"
}

module "ec2_webscraping" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "webscraping"
  instance_type  = "t3.micro"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[2]
  frontend_ports = [22, 5000]
  allowed_cidr_blocks = ["10.0.0.0/16"]
  user_data      = "${file("../../../scripts/setup/setup-vm.sh")}\n${replace(file("../../../scripts/setup/prod/setup-bot.sh"), "#!/bin/bash", "export BOT_TYPE=\"webscraping\"")}"
}

module "ec2_db" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "database"
  instance_type  = "t3.large"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[3]
  frontend_ports = [22, 3306, 6379]
  allowed_cidr_blocks = ["10.0.0.0/16"]
  user_data      = "${file("../../../scripts/setup/setup-vm.sh")}\n${file("../../../scripts/setup/prod/setup-db.sh")}"
}

output "nginx_public_ip" {
  description = "IP Público do Nginx Proxy"
  value       = module.ec2_nginx.public_ip
}

output "nginx_ssh" {
  description = "SSH para o Nginx"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${module.ec2_nginx.public_ip}"
}

output "backend_private_ip" {
  description = "IP Privado do Backend Monolito (para o Nginx)"
  value       = module.ec2_backend_1.private_ip
}

output "management_private_ip" {
  description = "IP Privado do Frontend Management System (para o Nginx)"
  value       = module.ec2_frontend_2.private_ip
}

output "institucional_private_ip" {
  description = "IP Privado do Frontend Institucional Website (para o Nginx)"
  value       = module.ec2_frontend_1.private_ip
}

resource "null_resource" "nginx_deploy" {
  triggers = {
    nginx_id           = module.ec2_nginx.instance_id
    backend_ip         = module.ec2_backend_1.private_ip
    management_ip      = module.ec2_frontend_2.private_ip
    institucional_ip   = module.ec2_frontend_1.private_ip
    setup_proxy_hash   = filemd5("../../../scripts/setup/prod/setup-proxy.sh")
    nginx_conf_hash    = filemd5("../../../services/proxy/nginx.conf.template")
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/../../../${var.key_name}.pem")
    host        = module.ec2_nginx.public_ip
  }

  # Preparar estrutura no /tmp
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/solarway/services/proxy",
      "mkdir -p /tmp/solarway/scripts/setup/prod"
    ]
  }

  # Transferir arquivos do proxy
  provisioner "file" {
    source      = "../../../services/proxy/docker-compose.yml"
    destination = "/tmp/solarway/services/proxy/docker-compose.yml"
  }

  provisioner "file" {
    source      = "../../../services/proxy/nginx.conf.template"
    destination = "/tmp/solarway/services/proxy/nginx.conf.template"
  }

  # Transferir scripts
  provisioner "file" {
    source      = "../../../scripts/setup/setup-vm.sh"
    destination = "/tmp/solarway/scripts/setup/setup-vm.sh"
  }

  provisioner "file" {
    source      = "../../../scripts/setup/prod/setup-proxy.sh"
    destination = "/tmp/solarway/scripts/setup/prod/setup-proxy.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'BACKEND_PRIVATE_IP=${module.ec2_backend_1.private_ip}' >> /tmp/solarway/.env",
      "echo 'MANAGEMENT_PRIVATE_IP=${module.ec2_frontend_2.private_ip}' >> /tmp/solarway/.env",
      "echo 'INSTITUCIONAL_PRIVATE_IP=${module.ec2_frontend_1.private_ip}' >> /tmp/solarway/.env",
      "chmod +x /tmp/solarway/scripts/setup/setup-vm.sh",
      "chmod +x /tmp/solarway/scripts/setup/prod/setup-proxy.sh",
      "sudo bash /tmp/solarway/scripts/setup/prod/setup-proxy.sh",
      "echo '\u2705 Nginx Proxy configurado! Healthcheck: '",
      "curl -sf http://localhost/health || echo 'Aguarde o container iniciar...'"
    ]
  }
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
