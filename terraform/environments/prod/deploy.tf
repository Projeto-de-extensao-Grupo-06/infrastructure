# =============================================================================
# Solarway PROD - deploy.tf
# Provisionamento dos serviços por EC2 via SSM Run Command (sem SSH, sem .pem)
# =============================================================================
#
# Contexto: As credenciais e configs são injetadas via user_data no main.tf
# usando templatefile() + base64encode(). Este arquivo define apenas as
# variáveis de runtime (IPs privados) que só existem após terraform apply,
# e que precisam ser passadas como .env para cada EC2 privada via SSM.
#
# O fluxo é:
#   1. main.tf provê as EC2 com setup-vm.sh + setup-<serviço>.sh via user_data
#   2. Os scripts leem /tmp/solarway/.env que foi escrito no user_data
#   3. O .env das EC2 privadas é construído por templatefile() e gravado
#      via aws_ssm_association + AWS-RunShellScript (sem SSH/null_resource)
# =============================================================================

# ── Variáveis de Runtime (todas vêm do .env via deploy script) ───────────────

variable "db_password" {
  description = "Senha do banco de dados MySQL"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Senha do Redis"
  type        = string
  sensitive   = true
}

variable "bot_secret" {
  description = "Secret do Bot WhatsApp"
  type        = string
  sensitive   = true
}

variable "email" {
  description = "E-mail de configuração para o Backend"
  type        = string
  sensitive   = true
}

variable "email_password" {
  description = "Senha do e-mail (App Password)"
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Nome do bucket S3 principal"
  type        = string
  default     = "solarway-datalake-trusted"
}

variable "db_username" {
  description = "Usuário do banco de dados MySQL"
  type        = string
  sensitive   = true
}

variable "redis_user" {
  description = "Usuário do Redis"
  type        = string
  default     = "default"
}

variable "github_username" {
  description = "Username do GitHub para pull de imagens privadas (ghcr.io)"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "PAT do GitHub para pull de imagens privadas (ghcr.io)"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Domínio público para configuração do SSL (ex: solarway.com.br)"
  type        = string
  default     = "solarway.test"
}

variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

variable "aws_session_token" {
  type      = string
  sensitive = true
}

variable "rabbitmq_default_user" {
  description = "Usuário do RabbitMQ"
  type        = string
  default     = "admin"
}

variable "rabbitmq_default_pass" {
  description = "Senha do RabbitMQ"
  type        = string
  default     = "0624"
}


# ── SSM Associations: Injeção de .env por serviço sem SSH ────────────────────
# Usamos aws_ssm_association com AWS-RunShellScript para escrever o .env
# correto em cada EC2 privada já provisionada. Isso substitui o null_resource.

resource "aws_ssm_association" "env_db" {
  name = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_db.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/db/mysql-init",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.db.tmpl", {
        db_username         = var.db_username
        db_password         = var.db_password
        redis_password      = var.redis_password
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/db/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/db/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/services/db/mysql-init/init.sql << 'SQLEOF'",
      file("../../../services/db/mysql-init/init.sql"),
      "SQLEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-db.sh"),
      "EOF",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}

resource "aws_ssm_association" "env_backend_1" {
  depends_on = [aws_ssm_association.env_db]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_backend_1.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/backend/monolith",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.backend.tmpl", {
        db_private_ip       = module.ec2_db.private_ip
        db_password         = var.db_password
        bucket_name         = var.bucket_name
        email               = var.email
        email_password      = var.email_password
        bot_secret          = var.bot_secret
        github_username     = var.github_username
        github_access_token = var.github_token
        aws_access_key      = var.aws_access_key
        aws_secret_key      = var.aws_secret_key
        aws_session_token   = var.aws_session_token
        rabbitmq_default_user = var.rabbitmq_default_user
        rabbitmq_default_pass = var.rabbitmq_default_pass
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/backend/monolith/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/backend/monolith/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-backend.sh"),
      "EOF",
      "export BACKEND_TYPE='monolith'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}

resource "aws_ssm_association" "env_backend_2" {
  depends_on = [aws_ssm_association.env_db]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_backend_2.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/backend/microservice",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.backend.tmpl", {
        db_private_ip       = module.ec2_db.private_ip
        db_password         = var.db_password
        bucket_name         = var.bucket_name
        email               = var.email
        email_password      = var.email_password
        bot_secret          = var.bot_secret
        github_username     = var.github_username
        github_access_token = var.github_token
        aws_access_key      = var.aws_access_key
        aws_secret_key      = var.aws_secret_key
        aws_session_token   = var.aws_session_token
        rabbitmq_default_user = var.rabbitmq_default_user
        rabbitmq_default_pass = var.rabbitmq_default_pass
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/backend/microservice/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/backend/microservice/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-backend.sh"),
      "EOF",
      "export BACKEND_TYPE='microservice'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}

resource "aws_ssm_association" "env_frontend_1" {
  depends_on = [aws_ssm_association.env_backend_1]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_frontend_1.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/frontend/institucional-website",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.frontend.tmpl", {
        backend_1_ip        = module.ec2_backend_1.private_ip
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/frontend/institucional-website/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/frontend/institucional-website/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-frontend.sh"),
      "EOF",
      "export FRONTEND_TYPE='institutional'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}

resource "aws_ssm_association" "env_frontend_2" {
  depends_on = [aws_ssm_association.env_backend_1]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_frontend_2.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/frontend/management-system",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.frontend.tmpl", {
        backend_1_ip        = module.ec2_backend_1.private_ip
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/frontend/management-system/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/frontend/management-system/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-frontend.sh"),
      "EOF",
      "export FRONTEND_TYPE='management'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}

resource "aws_ssm_association" "env_bot" {
  depends_on = [aws_ssm_association.env_backend_1]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_chatbot.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/bot",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.bot.tmpl", {
        backend_1_ip        = module.ec2_backend_1.private_ip
        db_private_ip       = module.ec2_db.private_ip
        nginx_public_ip     = module.ec2_nginx.public_ip
        bot_secret          = var.bot_secret
        db_username         = var.db_username
        db_password         = var.db_password
        redis_user          = var.redis_user
        redis_password      = var.redis_password
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/bot/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/bot/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-bot.sh"),
      "EOF",
      "export BOT_TYPE='chatbot'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}

resource "aws_ssm_association" "env_webscraping" {
  depends_on = [aws_ssm_association.env_db]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_webscraping.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/web-scrapping",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.bot.tmpl", {
        backend_1_ip        = module.ec2_backend_1.private_ip
        db_private_ip       = module.ec2_db.private_ip
        nginx_public_ip     = module.ec2_nginx.public_ip
        bot_secret          = var.bot_secret
        db_username         = var.db_username
        db_password         = var.db_password
        redis_user          = var.redis_user
        redis_password      = var.redis_password
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/web-scrapping/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/web-scrapping/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-bot.sh"),
      "EOF",
      "export BOT_TYPE='webscraping'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}# ── Nginx Proxy: Configuração Dinâmica de Ingress ───────────────────────────
# Isso garante que o Nginx sempre tenha os IPs privados atuais das outras VMs
# sem precisar recriar a instância de proxy.

resource "aws_ssm_association" "env_proxy" {
  name = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_nginx.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/proxy",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      "BACKEND_PRIVATE_IP=${module.ec2_backend_1.private_ip}",
      "MANAGEMENT_PRIVATE_IP=${module.ec2_frontend_2.private_ip}",
      "INSTITUCIONAL_PRIVATE_IP=${module.ec2_frontend_1.private_ip}",
      "N8N_PRIVATE_IP=${module.ec2_chatbot.private_ip}",
      "WAHA_PRIVATE_IP=${module.ec2_chatbot.private_ip}",
      "DOMAIN=${var.domain}",
      "EMAIL=${var.email}",
      "GITHUB_USERNAME=${var.github_username}",
      "GITHUB_ACCESS_TOKEN=${var.github_token}",
      "ENVEOF",
      "cat > /tmp/solarway/services/proxy/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/proxy/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/services/proxy/nginx.conf.template << 'CONFEOF'",
      file("../../../services/proxy/nginx.conf.template"),
      "CONFEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("./scripts/setup-proxy.sh"),
      "EOF",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}
