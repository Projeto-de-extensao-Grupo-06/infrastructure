module "vpc" {
  source = "../../modules/vpc"

  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]
  azs             = ["us-east-1a"]
}

module "ec2_qa" {
  source = "../../modules/ec2"

  environment   = var.environment
  instance_name = "qa-machine"
  instance_type = var.instance_type
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnet_ids[0]
  key_name      = var.key_name
  
  frontend_ports      = [22, 80, 443, 8000, 8080, 8081, 8082, 5678, 3000, 3306, 3307]
  allowed_cidr_blocks = ["0.0.0.0/0"]
  user_data           = file("../../../scripts/setup/setup-qa.sh")
}

output "public_ip" {
  description = "IP Público da Instância de QA"
  value       = module.ec2_qa.public_ip
}

output "ssh_command" {
  description = "Comando para acessar a instância via SSH"
  value       = "ssh -i ../../../${var.key_name}.pem ubuntu@${module.ec2_qa.public_ip}"
}

resource "null_resource" "deploy" {
  # Dispara o deploy sempre que mudar a instância ou o .env local
  triggers = {
    instance_id = module.ec2_qa.instance_id
    env_hash    = filemd5("../../../.env")
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/../../../${var.key_name}.pem")
    host        = module.ec2_qa.public_ip
  }

  # 1. Preparar pasta remota
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/solarway"
    ]
  }

  # 2. Enviar .env e pasta de serviços
  provisioner "file" {
    source      = "../../../.env"
    destination = "/tmp/solarway/.env"
  }

  provisioner "file" {
    source      = "../../../services"
    destination = "/tmp/solarway/services"
  }

  # 3. Subir containers (com wait loop robusto para Docker)
  provisioner "remote-exec" {
    inline = [
      "cd /tmp/solarway",
      "echo '➡️ Aguardando o Docker ser instalado e iniciado (User Data)...'",
      "while ! sudo docker version >/dev/null 2>&1; do sleep 5; done",
      "echo '🔐 Autenticando no GHCR...'",
      "export GITHUB_USERNAME=$(grep GITHUB_USERNAME .env | cut -d'=' -f2 | tr -d '\r')",
      "export GITHUB_ACCESS_TOKEN=$(grep GITHUB_ACCESS_TOKEN .env | cut -d'=' -f2 | tr -d '\r')",
      "echo $GITHUB_ACCESS_TOKEN | sudo docker login ghcr.io -u $GITHUB_USERNAME --password-stdin",
      "echo '🐳 Docker pronto e autenticado! Iniciando Containers...'",
      "cd services/db && sudo docker compose --env-file ../../.env up -d",
      "sleep 5",
      "cd ../backend/monolith && sudo docker compose --env-file ../../../.env up -d",
      "cd ../microservice && sudo docker compose --env-file ../../../.env up -d",
      "cd ../../frontend/management-system && sudo docker compose --env-file ../../../.env up -d",
      "cd ../institucional-website && sudo docker compose --env-file ../../../.env up -d",
      "cd ../../bot && sudo docker compose --env-file ../../.env up -d",
      "echo '✅ Deploy Solarway via /tmp finalizado!'"
    ]
  }
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
