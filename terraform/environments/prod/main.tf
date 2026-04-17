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
    DOMAIN=solarway.test
    EMAIL=admin@solarway.test
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
  route_table_id         = module.vpc_prod.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.ec2_nginx.primary_network_interface_id
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
  user_data            = "${file("../../../scripts/setup-vm.sh")}\n${replace(file("./scripts/setup-frontend.sh"), "#!/bin/bash", "export FRONTEND_TYPE=\"institutional\"")}"
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
  user_data            = "${file("../../../scripts/setup-vm.sh")}\n${replace(file("./scripts/setup-frontend.sh"), "#!/bin/bash", "export FRONTEND_TYPE=\"management\"")}"
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
  user_data            = "${file("../../../scripts/setup-vm.sh")}\n${replace(file("./scripts/setup-backend.sh"), "#!/bin/bash", "export BACKEND_TYPE=\"monolith\"")}"
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
  user_data            = "${file("../../../scripts/setup-vm.sh")}\n${replace(file("./scripts/setup-backend.sh"), "#!/bin/bash", "export BACKEND_TYPE=\"microservice\"")}"
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
  user_data            = "${file("../../../scripts/setup-vm.sh")}\n${replace(file("./scripts/setup-bot.sh"), "#!/bin/bash", "export BOT_TYPE=\"chatbot\"")}"
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
  user_data            = "${file("../../../scripts/setup-vm.sh")}\n${replace(file("./scripts/setup-bot.sh"), "#!/bin/bash", "export BOT_TYPE=\"webscraping\"")}"
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
  user_data            = "${file("../../../scripts/setup-vm.sh")}\n${file("./scripts/setup-db.sh")}"
}

output "nginx_public_ip" {
  description = "IP Público do Nginx Proxy"
  value       = module.ec2_nginx.public_ip
}

output "nginx_ssm_connect" {
  description = "Comando para conectar no Nginx Proxy via SSM"
  value       = "aws ssm start-session --target ${module.ec2_nginx.instance_id}"
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
