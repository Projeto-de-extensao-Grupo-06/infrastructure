output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Lista com os IDs das subnets públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Lista com os IDs das subnets privadas"
  value       = aws_subnet.private[*].id
}

output "private_nacl_ids" {
  description = "IDs das NACLs privadas"
  value       = aws_network_acl.private[*].id
}

output "public_route_table_id" {
  description = "ID do Route Table Público"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID do Route Table Privado (Main por padrão neste mock)"
  value       = aws_vpc.this.main_route_table_id
}
