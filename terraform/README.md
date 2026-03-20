# Infraestrutura AWS (Terraform) - SolarWay

Este diretório armazena o código de provisão de infraestrutura (IaC) via Terraform, segmentado em ambientes operacionais distintos: **qa** e **prod**.

## Estrutura Modular

As definições de infraestrutura utilizam módulos padronizados em `modules/` para controle de consistência:

- **vpc**: Provisionamento de VPC, Internet Gateways, Subnets baseadas em escopo (Públicas/Privadas) e definição de Tabelas de Roteamento IP.
- **ec2**: Provisionamento computacional usando AMI padronizado (Ubuntu 22.04 LTS) associado a esquemas dinâmicos de Security Groups.
- **s3**: Provisionamento de Buckets S3 integrando criptografia nativa (AWS KMS) e negação ostensiva de acesso público, formatados para compor um Data Lake.

---

## Ambiente Operacional: QA (`environments/qa`)

Ambiente (anteriormente `dev`) configurado com foco em validação funcional rápida e integração consolidada:

- **1 VPC Single-AZ** (1 subnet pública e 1 privada).
- **1 Instância EC2 (`t3.large`)**: Concentra a hospedagem simultânea de todas as stacks de containers (`db`, `backend`, `frontend`, `bot`). Possui estratégia de downgrade automático para `t3.medium` ou `t3.small` em contas de estudante com restrição de cota.
- **3 Buckets S3 (Data Lake)**: Arquitetura em três zonas de processamento unificadas (`bronze`, `silver` e `gold`).

---

## Ambiente Operacional: PROD (`environments/prod`)

Ambiente escalonado com ênfase em alta disponibilidade (HA), isolamento de rede e topologia focada na arquitetura AWS corporativa do projeto:

- **VPC Multicamadas** (`10.0.0.0/16`).
- **Subnets Públicas Multi-AZ**: Zona desmilitarizada contendo instâncias do **Nginx Proxy** destinadas a roteamento HTTP/HTTPS e SSL Termination. **Única camada com exposição pública (0.0.0.0/0)**.
- **Subnets Privadas e Camadas Sub-redes Isoladas**: Todas as instâncias internas são restritas ao tráfego do **VPC CIDR (`10.0.0.0/16`)** para maior segurança.
  - **Zone A ("Frontend")**: Instâncias separadas para `institutional-website` e `management-system`.
  - **Zone B ("Backend")**: Clusterização isolada distinguindo `monolith` e `microservices`.
  - **Zone C ("Automation")**: Zona de processadores de IA assíncronos (n8n, WAHA, Webscraping).
  - **Zone D ("Persistence")**: Região protegida dedicada estritamente ao tráfego do pool de conexões com os bancos de dados (MySQL, Redis).
- **Buckets S3**: Instâncias seguras de armazenamento (`raw`, `trusted`, `refined`).

## Execução e Aplicação de Mudanças

O provisionamento segue o fluxo de trabalho imutável via CLI Terraform. Navegue até o módulo do ambiente alvo e inicie os operadores padrões:

```bash
cd environments/qa
# Inicialização de dependências backend/providers
terraform init

# Avaliação do pipeline de recursos
terraform plan

# Aplicação definitiva do plano sobre a infraestrutura designada
terraform apply
```
