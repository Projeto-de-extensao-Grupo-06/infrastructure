
module "vpc" {
  source = "../../modules/vpc"

  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]
  azs             = ["us-east-1a"]
}

# Lê o .env local e outros scripts para injeção via user_data
locals {
  env_content    = file("../../../.env")
  setup_vm_content = file("../../../scripts/setup-vm.sh")
  setup_qa_content = file("./scripts/setup-qa.sh")

  # Files
  compose_db        = file("../../../services/db/docker-compose.yml")
  compose_monolith  = file("../../../services/backend/monolith/docker-compose.yml")
  compose_micro     = file("../../../services/backend/microservice/docker-compose.yml")
  compose_bot       = file("../../../services/bot/docker-compose.yml")
  compose_mgmt      = file("../../../services/frontend/management-system/docker-compose.yml")
  compose_inst      = file("../../../services/frontend/institucional-website/docker-compose.yml")
  compose_proxy     = file("../../../services/proxy/docker-compose.yml")
  compose_webscrapping = file("../../../services/web-scrapping/docker-compose.yml")
  proxy_tpl         = file("../../../services/proxy/nginx.conf.template")
  nginx_conf        = file("../../../services/proxy/nginx.conf")

  # Bot/N8N Files
  bot_n8n_dockerfile = file("../../../services/bot/n8n/Dockerfile")
  bot_n8n_init       = file("../../../services/bot/n8n/init-import.sh")
  bot_config_ai      = file("../../../services/bot/whatsapp-bot-ai.json")
  bot_config         = file("../../../services/bot/whatsapp-bot.json")

  # DB Files
  db_init_sql        = file("../../../services/db/mysql-init/init.sql")

  # Renderiza o script completo usando o template
  rendered_bootstrap = templatefile("bootstrap_qa.sh.tpl", {
    env_content      = local.env_content
    setup_vm_content = local.setup_vm_content
    setup_qa_content = local.setup_qa_content
    compose_db       = local.compose_db
    compose_monolith = local.compose_monolith
    compose_micro    = local.compose_micro
    compose_bot      = local.compose_bot
    compose_mgmt     = local.compose_mgmt
    compose_inst     = local.compose_inst
    compose_proxy    = local.compose_proxy
    compose_webscrapping = local.compose_webscrapping
    proxy_tpl        = local.proxy_tpl
    
    # Novos arquivos
    nginx_conf         = local.nginx_conf
    bot_n8n_dockerfile = local.bot_n8n_dockerfile
    bot_n8n_init       = local.bot_n8n_init
    bot_config_ai      = local.bot_config_ai
    bot_config         = local.bot_config
    db_init_sql        = local.db_init_sql
  })
}

# Upload do script para o S3 para contornar o limite de 16KB do User Data
resource "aws_s3_object" "bootstrap_script" {
  bucket  = module.s3_bronze.bucket_id
  key     = "scripts/bootstrap_qa.sh"
  content = local.rendered_bootstrap
  
  # Garante que o bucket existe antes de tentar o upload
  depends_on = [module.s3_bronze]
}

module "ec2_qa" {
  source = "../../modules/ec2"

  environment          = var.environment
  instance_name        = "qa-machine"
  instance_type        = var.instance_type
  vpc_id               = module.vpc.vpc_id
  subnet_id            = module.vpc.public_subnet_ids[0]
  iam_instance_profile = "LabInstanceProfile"

  frontend_ports      = [80, 443, 5678, 3000]
  allowed_cidr_blocks = ["0.0.0.0/0"]

  # User Data robusto: baixa o script real do S3 e executa
  user_data = <<-EOT
    #!/bin/bash
    apt-get update && apt-get install -y awscli
    aws s3 cp s3://${module.s3_bronze.bucket_id}/scripts/bootstrap_qa.sh /tmp/bootstrap_qa.sh
    chmod +x /tmp/bootstrap_qa.sh
    /bin/bash /tmp/bootstrap_qa.sh
  EOT
}

output "public_ip" {
  description = "IP Público da Instância de QA"
  value       = module.ec2_qa.public_ip
}

output "ssm_connect" {
  description = "Comando para acessar a instância via SSM (sem SSH/pem)"
  value       = "aws ssm start-session --target ${module.ec2_qa.instance_id}"
}

module "s3_bronze" {
  source = "../../modules/s3"

  environment = var.environment
  bucket_name = var.bucket_bronze_name
}

module "s3_silver" {
  source = "../../modules/s3"

  environment = var.environment
  bucket_name = var.bucket_silver_name
}

module "s3_gold" {
  source = "../../modules/s3"

  environment = var.environment
  bucket_name = var.bucket_gold_name
}
