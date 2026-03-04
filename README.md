# Solarize - Infraestrutura e Orquestração (Docker & Terraform)

Bem-vindo ao repositório central de infraestrutura do projeto Solarize.

Este repositório consolidou todos os arquivos de orquestração (`docker-compose.yml`), automações, painéis, proxy e infraestrutura como código (IaC) divididos em partes modulares.

---

## 🌳 Árvore de Diretórios

O projeto está dividido nas seguintes camadas estruturais:

```text
docker-composes/
├── apps/               # Aplicações proprietárias (Backend, Management System, Website)
├── bot/                # Infraestrutura do Bot do WhatsApp (Waha, N8N, Redis)
├── proxy/              # Proxy Reverso (Nginx) e certificados SSL (Certbot)
├── storage/            # Bancos de Dados e Caching (MySQL, Redis)
└── terraform/          # Infraestrutura como Código na AWS
    ├── environments/   # Ambientes (dev, prod) e invocação dos módulos
    ├── modules/        # Definição modular de EC2, S3, VPCs
    └── scripts/        # Automações de instalação (setup.sh)
```

---

## 🚀 Como o Deploy é Feito Atualmente?

O deploy de todo esse ambiente na nuvem é 100% automatizado, seguindo a abordagem de imagens pré-compiladas (Mirror de Docker Hub) e Infraestrutura como Código.

### 1. Build de Imagens 🐳

Não há build do código-fonte (Spring Boot, Vite) acontecendo dentro dos servidores de produção. Os desenvolvedores realizam o *build* local (ou via pipeline de CI/CD) de cada projeto e fazem o `push` para o Docker Hub:

- `seu_usuario/springboot-web-backend:latest`
- `seu_usuario/management-system:latest`
- `seu_usuario/institutional-website:latest`

### 2. Infraestrutura na AWS ☁️

O provisionamento da arquitetura na nuvem (na AWS) é executado via **Terraform** localizado na pasta `terraform/environments/dev`. Quando o comando `terraform apply` é executado, ele sobe:

- VPC, Subnets, Internet Gateways.
- Buckets S3 (Datalake).
- A **máquina EC2** contendo a regra de permissões necessária.

### 3. Automação de Startup (User Data) ⚙️

Durante a inicialização da instáncia EC2 (*User Data*), a AWS injeta e executa automaticamente o script localizado em `terraform/scripts/setup.sh`. Esse script:

1. Instala todos os pré-requisitos e o Docker de forma automatizada.
2. Clona **este repositório** na pasta `/home/ubuntu/docker-composes`.
3. Navega pelas pastas `storage`, `proxy`, `bot` e `apps`, executando um `docker compose pull` seguido de `docker compose up -d`.
4. Todos os serviços começam a rodar, baixando as imagens publicadas do Docker Hub, instantaneamente.

> Para saber mais sobre como gerenciar as chaves dos arquivos `.env` ou interagir no Docker Hub, acesse o guia de cada pasta específica!

---

## ⚠️ LEITURA DE MÓDULOS

Para garantir o funcionamento correto e evitar erros de rede, banco de dados ou compilação de modo estendido local, **cada pasta possui o seu próprio arquivo `README.md` específico**.

A subida arbitrária das stacks não é suportada e resultará em falhas de dependências se não for feita em ordem. O script automatizado da EC2 já obedece a ordem correta, que é:

1. **Storage** (Cria a rede primária)
2. **Apps / Bot / Proxy**

Ciente da estrutura acima, navegue para o diretório de sua escolha e aproveite a arquitetura modular!
