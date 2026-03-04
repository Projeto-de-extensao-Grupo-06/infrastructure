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
  frontend_ports = [22, 80, 443]
}

module "ec2_frontend_1" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "frontend-1"
  instance_type  = "t3.small"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[0]
  frontend_ports = [22, 3000, 8080, 8081]
}

module "ec2_frontend_2" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "frontend-2"
  instance_type  = "t3.small"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[0]
  frontend_ports = [22, 3000, 8080, 8081]
}

module "ec2_backend_1" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "backend-1"
  instance_type  = "t3.medium"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[1]
  frontend_ports = [22, 8000]
}

module "ec2_backend_2" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "backend-2"
  instance_type  = "t3.medium"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[1]
  frontend_ports = [22, 8000]
}

module "ec2_chatbot" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "chatbot"
  instance_type  = "t3.small"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[2]
  frontend_ports = [22, 3000, 5678]
}

module "ec2_webscraping" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "webscraping"
  instance_type  = "t3.micro"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[2]
  frontend_ports = [22, 5000]
}

module "ec2_db" {
  source = "../../modules/ec2"

  environment    = "prod"
  instance_name  = "database"
  instance_type  = "t3.large"
  vpc_id         = module.vpc_prod.vpc_id
  subnet_id      = module.vpc_prod.private_subnet_ids[3]
  frontend_ports = [22, 3306, 6379]
}

module "s3_raw" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarize-datalake-raw"
}

module "s3_trusted" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarize-datalake-trusted"
}

module "s3_refined" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarize-datalake-refined"
}
