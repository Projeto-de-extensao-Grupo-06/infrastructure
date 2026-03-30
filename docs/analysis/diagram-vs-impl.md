| Componente | Diagrama Python | Terraform Atual | Ação |
|------------|-----------------|-----------------|------|
| VPC CIDR | 10.0.0.0/26 | 10.0.0.0/16 | Corrigir |
| Frontend | 10.0.0.0/29 | 10.0.2.0/24 | Corrigir |
| Backend | 10.0.0.0/29 | 10.0.3.0/24 | Corrigir |
| NACLs | Sim | Não | Adicionar |
| IAM Role | Não | Não | Adicionar |
| S3 Endpoint | Não | Não | Adicionar |
