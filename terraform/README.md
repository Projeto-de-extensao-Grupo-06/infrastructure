# Infraestrutura AWS (Terraform) - SolarWay

Este diretório armazena o código de provisão de infraestrutura (IaC) via Terraform, segmentado em ambientes operacionais distintos: **dev** e **prod**.

## Estrutura Modular

As definições de infraestrutura utilizam módulos padronizados em `modules/` para controle de consistência:

- **vpc**: Provisionamento de VPC, Internet Gateways, Subnets baseadas em escopo (Públicas/Privadas) e definição de Tabelas de Roteamento IP.
- **ec2**: Provisionamento computacional usando AMI padronizado (Ubuntu 22.04 LTS) associado a esquemas dinâmicos de Security Groups.
- **s3**: Provisionamento de Buckets S3 integrando criptografia nativa (AWS KMS) e negação ostensiva de acesso público, formatados para compor um Data Lake.

---

## Ambiente Operacional: DEV (`environments/dev`)

Ambiente configurado com foco em validação funcional e integração mínima:

- **1 VPC Single-AZ** (1 subnet pública e 1 privada).
- **1 Instância EC2 (`t3.medium`)**: Concentra a hospedagem simultânea de todas as stacks de containers (`storage`, `bot`, `apps`). **Este modelo ignora balanceamentos de carga front-end e proxies reversos geridos nativamente pela AWS**.
- **3 Buckets S3**: Arquitetura padrão em três zonas de processamento (`raw`, `trusted`, `refined`).

---

## Ambiente Operacional: PROD (`environments/prod`)

Ambiente escalonado com ênfase em alta disponibilidade (HA), isolamento de rede e topologia focada na arquitetura AWS corporativa do projeto:

- **VPC Multicamadas** (`10.0.0.0/16`).
- **Subnets Públicas Multi-AZ**: Zona desmilitarizada contendo instâncias do **Nginx Proxy** destinadas a roteamento HTTP/HTTPS e SSL Termination.
- **Subnets Privadas e Camadas Sub-redes Isoladas**:
  - **Zone A ("Frontend")**: Pool de contêineres frontais gerenciais e painéis web (React/Vite).
  - **Zone B ("Backend")**: Clusterização isolada rodando a API principal (Spring Boot).
  - **Zone C ("Automation")**: Zona de processadores de IA assíncronos (n8n, WAHA, Webscraping).
  - **Zone D ("Persistence")**: Região protegida da área externa e dedicada estritamente ao tráfego do pool de conexões com os bancos de dados (MySQL, Redis).
- **Buckets S3**: Instâncias seguras de armazenamento formando o Data Lake corporativo.

## Execução e Aplicação de Mudanças

O provisionamento segue o fluxo de trabalho imutável via CLI Terraform. Navegue até o módulo do ambiente alvo e inicie os operadores padrões:

```bash
cd environments/dev
# Inicialização de dependências backend/providers
terraform init

# Avaliação do pipeline de recursos (Dry-run analítico)
terraform plan

# Aplicação definitiva do plano sobre a infraestrutura designada
terraform apply
```
