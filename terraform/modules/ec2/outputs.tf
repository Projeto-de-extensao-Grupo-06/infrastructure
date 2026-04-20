output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "IP Público da instância EC2"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "IP Privado da instância EC2"
  value       = aws_instance.this.private_ip
}

output "primary_network_interface_id" {
  description = "ID da placa de rede (Usado para tráfego NAT)"
  value       = aws_instance.this.primary_network_interface_id
}

output "security_group_id" {
  description = "ID do Security Group criado para a instância"
  value       = aws_security_group.this.id
}
