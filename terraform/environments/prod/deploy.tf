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
    commands = join("\n", [
      "mkdir -p /tmp/solarway/services/db",
      "cat > /tmp/solarway/services/db/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.db.tmpl", {
        db_password         = var.db_password
        redis_password      = var.redis_password
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF"
    ])
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
    commands = join("\n", [
      "mkdir -p /tmp/solarway/services/backend/monolith",
      "cat > /tmp/solarway/services/backend/monolith/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.backend.tmpl", {
        db_private_ip       = module.ec2_db.private_ip
        db_password         = var.db_password
        bucket_name         = var.bucket_name
        email               = var.email
        email_password      = var.email_password
        bot_secret          = var.bot_secret
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF"
    ])
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
    commands = join("\n", [
      "mkdir -p /tmp/solarway/services/backend/microservice",
      "cat > /tmp/solarway/services/backend/microservice/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.backend.tmpl", {
        db_private_ip       = module.ec2_db.private_ip
        db_password         = var.db_password
        bucket_name         = var.bucket_name
        email               = var.email
        email_password      = var.email_password
        bot_secret          = var.bot_secret
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF"
    ])
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
    commands = join("\n", [
      "mkdir -p /tmp/solarway/services/frontend/institucional-website",
      "cat > /tmp/solarway/services/frontend/institucional-website/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.frontend.tmpl", {
        backend_1_ip = module.ec2_backend_1.private_ip
      }),
      "ENVEOF"
    ])
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
    commands = join("\n", [
      "mkdir -p /tmp/solarway/services/frontend/management-system",
      "cat > /tmp/solarway/services/backend/management-system/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.frontend.tmpl", {
        backend_1_ip = module.ec2_backend_1.private_ip
      }),
      "ENVEOF"
    ])
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
    commands = join("\n", [
      "mkdir -p /tmp/solarway/services/bot",
      "cat > /tmp/solarway/services/bot/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.bot.tmpl", {
        backend_1_ip = module.ec2_backend_1.private_ip
        bot_secret   = var.bot_secret
      }),
      "ENVEOF"
    ])
  }
}
