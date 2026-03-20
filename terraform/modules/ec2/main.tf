resource "aws_security_group" "this" {
  name        = "solarway-sg-${var.instance_name}-${var.environment}"
  description = "Permite trafego de entrada nas portas configuradas"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.frontend_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "solarway-sg-${var.instance_name}-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = var.user_data != "" ? var.user_data : null

  tags = {
    Name        = "solarway-ec2-${var.instance_name}-${var.environment}"
    Environment = var.environment
  }
}
