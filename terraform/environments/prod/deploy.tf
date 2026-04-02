variable "db_password" {
  type      = string
  sensitive = true
  default   = "pass"
}

variable "redis_password" {
  type      = string
  sensitive = true
  default   = "pass"
}

variable "bot_secret" {
  type      = string
  sensitive = true
  default   = "secret"
}

variable "email" {
  type      = string
  sensitive = true
  default   = "admin@solarway"
}

variable "email_password" {
  type      = string
  sensitive = true
  default   = "pass"
}

variable "bucket_name" {
  type    = string
  default = "solarway-datalake-trusted"
}

variable "key_name" {
  type    = string
  default = "solarway-key"
}

variable "github_username" {
  type      = string
  sensitive = true
}

variable "github_token" {
  type      = string
  sensitive = true
}

resource "null_resource" "deploy_db" {
  triggers = {
    instance_id = module.ec2_db.instance_id
    env_hash    = md5(templatefile("${path.module}/templates/env.db.tmpl", {
      db_password          = var.db_password
      redis_password       = var.redis_password
      github_username      = var.github_username
      github_access_token  = var.github_token
    }))
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/../../../${var.key_name}.pem")
    host        = module.ec2_db.private_ip

    bastion_host        = module.ec2_nginx.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("${path.module}/../../../${var.key_name}.pem")
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /tmp/solarway/services/db", "mkdir -p /tmp/solarway/scripts/setup/prod"]
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/env.db.tmpl", {
      db_password          = var.db_password
      redis_password       = var.redis_password
      github_username      = var.github_username
      github_access_token  = var.github_token
    })
    destination = "/tmp/solarway/services/db/.env"
  }

  provisioner "file" {
    source      = "../../../services/db/"
    destination = "/tmp/solarway/services/db/"
  }

  provisioner "file" {
    source      = "../../../scripts/setup/setup-vm.sh"
    destination = "/tmp/solarway/scripts/setup/setup-vm.sh"
  }

  provisioner "file" {
    source      = "../../../scripts/setup/prod/setup-db.sh"
    destination = "/tmp/solarway/scripts/setup/prod/setup-db.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/solarway/scripts/setup/setup-vm.sh",
      "sed -i 's/\\r$//' /tmp/solarway/scripts/setup/prod/setup-db.sh",
      "chmod +x /tmp/solarway/scripts/setup/setup-vm.sh",
      "chmod +x /tmp/solarway/scripts/setup/prod/setup-db.sh",
      "cd /tmp/solarway && sudo bash scripts/setup/setup-vm.sh",
      "cd /tmp/solarway && sudo bash scripts/setup/prod/setup-db.sh",
      "sleep 30",
    ]
  }
}

resource "null_resource" "deploy_backend_1" {
  depends_on = [null_resource.deploy_db]
  triggers = { instance_id = module.ec2_backend_1.instance_id }
  connection {
    type  = "ssh"
    user  = "ubuntu"
    private_key = file("${path.module}/../../../${var.key_name}.pem")
    host  = module.ec2_backend_1.private_ip
    bastion_host        = module.ec2_nginx.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("${path.module}/../../../${var.key_name}.pem")
  }
  provisioner "remote-exec" { inline = ["mkdir -p /tmp/solarway/services/backend/monolith", "mkdir -p /tmp/solarway/scripts/setup/prod"] }
  provisioner "file" {
    content = templatefile("${path.module}/templates/env.backend.tmpl", {
      db_private_ip        = module.ec2_db.private_ip
      db_password          = var.db_password
      bucket_name          = var.bucket_name
      email                = var.email
      email_password       = var.email_password
      bot_secret           = var.bot_secret
      github_username      = var.github_username
      github_access_token  = var.github_token
    })
    destination = "/tmp/solarway/services/backend/monolith/.env"
  }
  provisioner "file" {
    source      = "../../../services/backend/monolith/"
    destination = "/tmp/solarway/services/backend/monolith/"
  }
  provisioner "file" {
    source      = "../../../scripts/setup/setup-vm.sh"
    destination = "/tmp/solarway/scripts/setup/setup-vm.sh"
  }
  provisioner "file" {
    source      = "../../../scripts/setup/prod/setup-backend.sh"
    destination = "/tmp/solarway/scripts/setup/prod/setup-backend.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "export BACKEND_TYPE=\"monolith\"",
      "sed -i 's/\\r$//' /tmp/solarway/scripts/setup/setup-vm.sh",
      "sed -i 's/\\r$//' /tmp/solarway/scripts/setup/prod/setup-backend.sh",
      "chmod +x /tmp/solarway/scripts/setup/setup-vm.sh",
      "chmod +x /tmp/solarway/scripts/setup/prod/setup-backend.sh",
      "cd /tmp/solarway && sudo bash scripts/setup/setup-vm.sh",
      "cd /tmp/solarway && sudo -E bash scripts/setup/prod/setup-backend.sh"
    ]
  }
}

resource "null_resource" "deploy_backend_2" {
  depends_on = [null_resource.deploy_db]
  triggers = { instance_id = module.ec2_backend_2.instance_id }
  connection {
    type  = "ssh"
    user  = "ubuntu"
    private_key = file("${path.module}/../../../${var.key_name}.pem")
    host  = module.ec2_backend_2.private_ip
    bastion_host        = module.ec2_nginx.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("${path.module}/../../../${var.key_name}.pem")
  }
  provisioner "remote-exec" { inline = ["mkdir -p /tmp/solarway/services/backend/microservice", "mkdir -p /tmp/solarway/scripts/setup/prod"] }
  provisioner "file" {
    content = templatefile("${path.module}/templates/env.backend.tmpl", {
      db_private_ip        = module.ec2_db.private_ip
      db_password          = var.db_password
      bucket_name          = var.bucket_name
      email                = var.email
      email_password       = var.email_password
      bot_secret           = var.bot_secret
      github_username      = var.github_username
      github_access_token  = var.github_token
    })
    destination = "/tmp/solarway/services/backend/microservice/.env"
  }
  provisioner "file" {
    source      = "../../../services/backend/microservice/"
    destination = "/tmp/solarway/services/backend/microservice/"
  }
  provisioner "file" {
    source      = "../../../scripts/setup/setup-vm.sh"
    destination = "/tmp/solarway/scripts/setup/setup-vm.sh"
  }
  provisioner "file" {
    source      = "../../../scripts/setup/prod/setup-backend.sh"
    destination = "/tmp/solarway/scripts/setup/prod/setup-backend.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "export BACKEND_TYPE=\"microservice\"",
      "sed -i 's/\\r$//' /tmp/solarway/scripts/setup/setup-vm.sh",
      "sed -i 's/\\r$//' /tmp/solarway/scripts/setup/prod/setup-backend.sh",
      "chmod +x /tmp/solarway/scripts/setup/setup-vm.sh",
      "chmod +x /tmp/solarway/scripts/setup/prod/setup-backend.sh",
      "cd /tmp/solarway && sudo bash scripts/setup/setup-vm.sh",
      "cd /tmp/solarway && sudo -E bash scripts/setup/prod/setup-backend.sh"
    ]
  }
}

resource "null_resource" "deploy_frontend_1" {
  depends_on = [null_resource.deploy_backend_1]
  triggers = { instance_id = module.ec2_frontend_1.instance_id }
  connection {
    type  = "ssh"
    user  = "ubuntu"
    private_key = file("${path.module}/../../../${var.key_name}.pem")
    host  = module.ec2_frontend_1.private_ip
    bastion_host        = module.ec2_nginx.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("${path.module}/../../../${var.key_name}.pem")
  }
  provisioner "remote-exec" { inline = ["mkdir -p /tmp/solarway/services/frontend/institucional-website", "mkdir -p /tmp/solarway/scripts/setup/prod"] }
  provisioner "file" {
    content = templatefile("${path.module}/templates/env.frontend.tmpl", {
      backend_1_ip = module.ec2_backend_1.private_ip
    })
    destination = "/tmp/solarway/services/frontend/institucional-website/.env"
  }
  provisioner "file" {
    source      = "../../../services/frontend/institucional-website/"
    destination = "/tmp/solarway/services/frontend/institucional-website/"
  }
  provisioner "file" {
    source      = "../../../scripts/setup/setup-vm.sh"
    destination = "/tmp/solarway/scripts/setup/setup-vm.sh"
  }
  provisioner "file" {
    source      = "../../../scripts/setup/prod/setup-frontend.sh"
    destination = "/tmp/solarway/scripts/setup/prod/setup-frontend.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "export FRONTEND_TYPE=\"institutional\"",
      "sed -i 's/\\r$//' /tmp/solarway/scripts/setup/setup-vm.sh",
      "sed -i 's/\\r$//' /tmp/solarway/scripts/setup/prod/setup-frontend.sh",
      "chmod +x /tmp/solarway/scripts/setup/setup-vm.sh",
      "chmod +x /tmp/solarway/scripts/setup/prod/setup-frontend.sh",
      "cd /tmp/solarway && sudo bash scripts/setup/setup-vm.sh",
      "cd /tmp/solarway && sudo -E bash scripts/setup/prod/setup-frontend.sh"
    ]
  }
}

resource "null_resource" "deploy_frontend_2" {
  depends_on = [null_resource.deploy_backend_1]
  triggers = { instance_id = module.ec2_frontend_2.instance_id }
  connection {
    type  = "ssh"
    user  = "ubuntu"
    private_key = file("${path.module}/../../../${var.key_name}.pem")
    host  = module.ec2_frontend_2.private_ip
    bastion_host        = module.ec2_nginx.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("${path.module}/../../../${var.key_name}.pem")
  }
  provisioner "remote-exec" { inline = ["mkdir -p /tmp/solarway/services/frontend/management-system", "mkdir -p /tmp/solarway/scripts/setup/prod"] }
  provisioner "file" {
    content = templatefile("${path.module}/templates/env.frontend.tmpl", {
      backend_1_ip = module.ec2_backend_1.private_ip
    })
    destination = "/tmp/solarway/services/frontend/management-system/.env"
  }
  provisioner "file" {
    source      = "../../../services/frontend/management-system/"
    destination = "/tmp/solarway/services/frontend/management-system/"
  }
  provisioner "file" {
    source      = "../../../scripts/setup/setup-vm.sh"
    destination = "/tmp/solarway/scripts/setup/setup-vm.sh"
  }
  provisioner "file" {
    source      = "../../../scripts/setup/prod/setup-frontend.sh"
    destination = "/tmp/solarway/scripts/setup/prod/setup-frontend.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "export FRONTEND_TYPE=\"management\"",
      "sed -i 's/\\r$//' /tmp/solarway/scripts/setup/setup-vm.sh",
      "sed -i 's/\\r$//' /tmp/solarway/scripts/setup/prod/setup-frontend.sh",
      "chmod +x /tmp/solarway/scripts/setup/setup-vm.sh",
      "chmod +x /tmp/solarway/scripts/setup/prod/setup-frontend.sh",
      "cd /tmp/solarway && sudo bash scripts/setup/setup-vm.sh",
      "cd /tmp/solarway && sudo -E bash scripts/setup/prod/setup-frontend.sh"
    ]
  }
}
