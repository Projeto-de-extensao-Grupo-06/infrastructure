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
  user_data           = "#!/bin/bash\necho 'User Data minimal - o setup real sera via remote-exec'"
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

  triggers = {
    instance_id = module.ec2_qa.instance_id
    env_hash    = filemd5("../../../.env")
    setup_vm    = filemd5("../../../scripts/setup/setup-vm.sh")
    setup_qa    = filemd5("../../../scripts/setup/setup-qa.sh")
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/../../../${var.key_name}.pem")
    host        = module.ec2_qa.public_ip
  }

  # Preparar pasta remota
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/solarway/scripts/setup"
    ]
  }

  # Enviar scripts de setup
  provisioner "file" {
    source      = "../../../scripts/setup/setup-vm.sh"
    destination = "/tmp/solarway/scripts/setup/setup-vm.sh"
  }

  provisioner "file" {
    source      = "../../../scripts/setup/setup-qa.sh"
    destination = "/tmp/solarway/scripts/setup/setup-qa.sh"
  }

  # Enviar .env e pasta de serviços
  provisioner "file" {
    source      = "../../../.env"
    destination = "/tmp/solarway/.env"
  }

  provisioner "file" {
    source      = "../../../services"
    destination = "/tmp/solarway/services"
  }

  # Executar o setup via scripts transferidos
  provisioner "remote-exec" {
    inline = [
      "cd /tmp/solarway",
      "echo '➡️ Ajustando URLs no .env para o IP Público: ${module.ec2_qa.public_ip}...'",
      "sed -i 's/localhost:8000/${module.ec2_qa.public_ip}:8000/g' .env",
      "echo '➡️ Iniciando setup da VM e deploy do ambiente...'",
      "chmod +x scripts/setup/setup-vm.sh scripts/setup/setup-qa.sh",
      "sudo bash scripts/setup/setup-qa.sh"
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
