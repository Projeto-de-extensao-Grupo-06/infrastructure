# Solarway - Infraestrutura e Docker Compose

Este repositório contém as configurações de infraestrutura (Cloud e Local) para o ecossistema **Solarway**.

Recentemente, a arquitetura da aplicação foi **pulverizada** (separada) em diferentes domínios para facilitar o gerenciamento, a escalabilidade e o deploy contínuo em contêineres independentes. Anteriormente centralizados em um formato mais monolítico ("apps"), os serviços foram segmentados nas seguintes categorias principais dentro do diretório `services/`:

## Estrutura do Repositório

- **`services/backend/`**: Contém as configurações para hospedar todo o código de processamento de dados.
  - `monolith/`: O backend monolítico principal da aplicação em Spring Boot.
  - `microservice/`: Microserviços apartados (ex: `schedule-notification`).
- **`services/frontend/`**: Contém as aplicações de interface do usuário.
  - `institucional-website/`: O site institucional voltado para apresentação.
  - `management-system/`: O sistema gerencial privado e painel de controle.
- **`services/bot/`**: A stack de automação inteligente de WhatsApp utilizando n8n, WAHA e Redis.
- **`services/web-scrapping/`**: Job batch de atualização de preços via Mercado Livre, executado a cada 24h.

Outras pastas relevantes no repositório geral:
- `proxy/`: Configurações de proxy reverso e balanceadores de carga.
- `scripts/`: Scripts executáveis Bash e PowerShell separados por ambiente (Local, QA, Produção) para deploy limpo.
- `terraform/`: Modelos de Infraestrutura como Código (IaC).

## Como utilizar

Cada diretório dentro de `services/` possui seu respectivo manifesto `docker-compose.yml` e dependências atreladas, acompanhados de um `README.md` contendo as instruções de configuração de ambiente e inicialização.

Para rodar e configurar um componente específico, acesse as documentações de cada sub-domínio:

- 📖 **[Documentação do Backend](./services/backend/README.md)**
- 📖 **[Documentação do Frontend](./services/frontend/README.md)**
- 📖 **[Documentação do Bot](./services/bot/README.md)**
- 📖 **[Documentação do Web Scrapping](./services/web-scrapping/README.md)**

---

## Início Rápido (Execução Local Completa)

Para testes, homologações ou desenvolvimento contínuo local, foram providenciados scripts que abstraem a complexidade do cluster e obedecem rigidamente à ordem cronológica de inicializações (Banco de Dados Primário ➔ Backend Originador da Rede ➔ Interfaces e Bots ➔ Web Scrapping).

Abra um terminal na **raiz** deste diretório e execute o script apropriado ao seu ecossistema:

**Windows (PowerShell):**
```powershell
.\scripts\global\setup-local.ps1
```

**Linux/Mac (Bash WSL):**
```bash
./scripts/global/setup-local.sh
```

Isso subirá de uma só vez o MySQL, o Redis-Multidb, o Monolito do Spring Boot, os contêineres do Sistema de Gerenciamento, do Site Institucional, dos serviços nativos do WhatsApp IA e o scheduler de web scrapping.

---

## 🗺️ Mapa Completo de URLs — Ambiente Local

O ponto de entrada único local é o **Nginx Proxy** na porta **80** (gerencial) e **81** (institucional). O `.env` define as portas de cada serviço.

### Interfaces de Usuário (via Proxy Nginx — porta 80/81)

| URL | Serviço | Container |
|-----|---------|-----------|
| `http://localhost/` | Management System | `management-system` |
| `http://localhost/institucional` | Site Institucional | `institutional-website` |
| `http://localhost/api` | API REST do Backend | `backend-service` |
| `http://localhost/schedule` | Schedule Notification | `schedule-notification` |
| `http://localhost/health` | Healthcheck do Proxy Nginx | `nginx-proxy` |

> [!NOTE]
> Todas as rotas passam pela **porta 80** — sem precisar especificar porta na URL. A porta 81 continua disponível como alias para o site institucional.

### Acesso direto por porta (host)

| URL | Serviço | Container | Uso |
|-----|---------|-----------|-----|
| `http://localhost:8000/api` | Backend Monolito | `backend-service` | Acesso direto sem proxy (Postman, curl) |
| `http://localhost:8082` | Schedule Notification | `schedule-notification` | Acesso direto sem proxy |
| `http://localhost:3307` | MySQL | `mysql-db` | Clientes de BD externos (DBeaver, TablePlus) |

> [!IMPORTANT]
> Internamente (Docker), os containers se comunicam via nome do container: `http://backend-service:8000`. As portas acima são apenas para acesso **externo do host**.

### Banco de Dados e Cache

| URL / Endpoint | Serviço | Container | Porta no host |
|----------------|---------|-----------|---------------|
| `localhost:3307` | MySQL principal | `mysql-db` | `PORT_MYSQL` (padrão: 3307) |
| `localhost:6379` | Redis principal (backend) | `redis-multidb` | `PORT_REDIS` (padrão: 6379) |
| `localhost:6380` | Redis do bot (n8n/WAHA) | `bot-redis` | `PORT_BOT_REDIS` (padrão: 6380) |
| `localhost:3306` | MySQL do microserviço | `microservice-db` | `PORT_MICROSERVICE_DB` (padrão: 3306) |

> [!NOTE]
> A porta `3307` (host) mapeia para `3306` dentro do container. Conectores JDBC **internos** sempre usam a porta `3306`. Use `3307` apenas para acesso externo (ex: DBeaver, TablePlus).

### Bot WhatsApp (n8n + WAHA)

| URL | Serviço | Container | Porta interna |
|-----|---------|-----------|---------------|
| `http://localhost:5678` | n8n (editor de fluxos) | `bot-n8n` | 5678 |
| `http://localhost:3000/dashboard` | WAHA (Dashboard) | `bot-waha` | 3000 |

> [!NOTE]
> Estes serviços agora utilizam **Acesso Direto por Porta** para evitar problemas de MIME type. O redirecionamento no proxy central (porta 80) foi mantido para conveniência.

### Web Scrapping (Job Batch)

| Serviço | Container | Frequência | Descrição |
|---------|-----------|------------|-----------|
| Web Scrapping Scheduler | `web-scrapping-scheduler` | A cada 24h | Atualiza preços da tabela `material_url` via Mercado Livre |

> [!NOTE]
> O web scrapping **não expõe porta alguma**. É um job batch interno que se conecta diretamente ao `mysql-db` pela rede `storage_network` e atualiza os preços dos materiais com dados do Mercado Livre.

---

## 🗺️ Mapa Completo de URLs — Ambiente QA (EC2 AWS)

No ambiente QA, todos os serviços rodam em **uma única VM EC2** (`t3.large`). Substitua `<IP_PUBLICO_QA>` pelo IP público da instância.

### Interfaces de Usuário (via Proxy Nginx)

| URL | Serviço |
|-----|---------|
| `http://<IP_PUBLICO_QA>/` | Management System |
| `http://<IP_PUBLICO_QA>/institucional` | Site Institucional |
| `http://<IP_PUBLICO_QA>/health` | Healthcheck do Proxy |

### API e Serviços (Acesso Direto)

| URL | Serviço | Porta |
|-----|---------|-------|
| `http://<IP_PUBLICO_QA>/api` | Backend Monolito — API REST (via proxy) | 80 |
| `http://<IP_PUBLICO_QA>/schedule` | Schedule Notification (via proxy) | 80 |
| `http://<IP_PUBLICO_QA>:5678/` | n8n (editor de fluxos WhatsApp) | 5678 |
| `http://<IP_PUBLICO_QA>:3000/dashboard` | Dashboard WAHA | 3000 |

> [!WARNING]
> As portas de banco de dados (`3306`, `3307`) **não devem ser expostas** publicamente em QA. Acesse-as apenas via SSH tunneling: `ssh -L 3307:localhost:3307 ubuntu@<IP_PUBLICO_QA> -i solarway.pem`
> O IP público é exibido automaticamente ao final da execução do `setup-qa.sh`.

---

## Deployments e Ambientes Segregados

Seguindo fidedignamente a arquitetura pulverizada da nuvem (onde sub-redes isolam frontends, backends e workers), a pasta `scripts/` detém gatilhos específicos de *User Data* para VMs isoladas:

- **`terraform/environments/qa/scripts/setup-qa.sh`**: Instala a infra inteira em uma única máquina Linux para rodadas de testes integrados.
- **`terraform/environments/prod/scripts/setup-[camada].sh`**: Cada arquivo deste atua nativamente ativando só a camada designada (`db`, `backend`, `frontend`, `bot`). 
  - **Diferenciação via Injeção**: Em produção, os scripts suportam as variáveis `FRONTEND_TYPE`, `BACKEND_TYPE` e `BOT_TYPE` para subir apenas o serviço específico daquela VM (ex: apenas Monolito ou apenas Website Institucional), otimizando recursos.


---

## Redes e Comunicação (Networks)

Para garantir conectividade direta e resolução de DNS interna nativa (abandonando a dependência legada e instável de acessos via IP ou pelo `host.docker.internal`), todos os módulos foram uniformizados para operar sob a mesma infraestrutura de conectividade.

- **`solarway_network`**: Rede em ponte (bridge) central para comunicação cruzada unificada (Backend ↔ Frontend ↔ Bot). 
  - O **`backend/monolith/docker-compose.yml`** assume o papel de hospedar e construir a definição original da rede. Portanto, a orientação é sempre **iniciar o serviço do Backend primeiro**.
  - Todos os demais módulos atuam como parasitas na rede e se anexam em modo leitura (`external: true`).
- **`storage_network`**: Rede focada ao tráfego de persistências cruas atrelada ao Data Lake e microsserviços pesados adjacentes.

**Resolução por Nomes**: Em decorrência do alinhamento, os serviços dentro da *solarway_network* atingem uns aos outros pelo `container_name`. Por exemplo, o N8N conecta-se ao servidor Spring pela URL dinâmica: `http://backend-service:8000`.
---

## Proxy Reverso Central (Nginx)

O diretório `services/proxy/` contém o **ponto de entrada único** da aplicação, simulando localmente o que a EC2 pública (`ec2_nginx`) faz na AWS.

### Arquitetura do Proxy

```
                    ┌─────────────────────────────┐
Internet ──────────►│  nginx-proxy (ec2_nginx)     │
                    │  Porta 80  → Management      │
                    │  Porta 81  → Institucional   │
                    └──────┬──────────────┬────────┘
                           │              │
              ┌────────────▼──┐     ┌─────▼─────────────┐
              │ management-   │     │ institutional-     │
              │ system:80     │     │ website:80         │
              │ (Nginx próprio)│    │ (Nginx próprio)    │
              │  ├── / assets  │    │  ├── / assets      │
              │  └── /api/ ──►│    │  └── /api/ ────►   │
              └───────────────┘    └────────────────────┘
                        │                    │
                        └─────────►  backend-service:8000
```

**Responsabilidades:**
- **Proxy central** (`nginx.conf`): Roteador puro — apenas encaminha o tráfego para o container correto. Não duplica lógica de `/api/`.
- **Nginx de cada frontend** (`nginx.conf.template`): Serve os assets React e proxia `/api/` para o backend via `BACKEND_URL`.

### Acesso Local

| URL | Destino | Nota |
|-----|---------|------|
| `http://localhost/` | Management System | Redireciona para `/ui/management` |
| `http://localhost/ui/management` | Management System | Rota direta do painel gerencial |
| `http://localhost:81/` | Site Institucional | Acesso direto local (porta 81) |
| `http://localhost/health` | Healthcheck do proxy | Retorna `solarway-proxy OK` |

### Produção AWS

Na AWS, o `ec2_nginx` na subnet pública roteia para IPs privados da VPC:
- `:8080` → VM `frontend-1` (management) — IP privado `10.0.2.x`
- `:8081` → VM `frontend-2` (institucional) — IP privado `10.0.2.x`

O `nginx.conf.template` usa `envsubst` para injetar os IPs reais via variáveis de ambiente providas pelo Terraform.

### Roadmap HTTPS (Let's Encrypt)

> [!NOTE]
> HTTPS será habilitado após validação do deploy em HTTP na AWS. Requer domínio registrado.

**Fluxo planejado:**
1. **Porto :80** no `ec2_nginx` → redirect 301 → `:443`
2. **Porto :443** → SSL termination com certificado Let's Encrypt via Certbot
3. `setup-proxy.sh` rodará `certbot certonly --standalone` automaticamente
4. Variáveis `DOMAIN` e `ADMIN_EMAIL` serão adicionadas ao `.env`

> [!WARNING]
> **Status atual**: Deploy HTTP local ✅ validado. Deploy HTTPS em AWS 🔲 pendente de domínio registrado.

---

## Infraestrutura como Código - AWS (Terraform)

No repertório **`terraform/`**, residem os scripts padronizados focados em alocação de EC2, S3 e VPCs. Seu workflow modular foi pensado com estratégias de escala isoladas por ambiente:

- **Ambiente QA (`environments/qa`)**: (Anteriormente `dev`). VPC desenhada em Single-AZ. Consolida todos os serviços em uma única VM (`t3.large`) para testes rápidos. Provisiona as três fases do Data Lake: `bronze`, `silver` e `gold`.
- **Ambiente PROD (`environments/prod`)**: Topologia de Alta Disponibilidade. Provisiona Sub-redes Públicas (Proxy) e Privadas, isolando rigidamente Frontend, Backend, Automations e Datastore Persistence.

## Deploy Automatizado (QA)

Para o ambiente de QA, o processo foi totalmente automatizado via Terraform. O script principal agora realiza todo o ciclo de vida:

1. **Provisionamento**: Cria a instância EC2 e a rede.
2. **Transferência de Código (SCP)**: O Terraform utiliza um provisionador `file` para enviar automaticamente a pasta `services/` e o seu `.env` para a VM.
3. **Setup Remoto**: Após o envio, o Terraform executa o script de inicialização (`scripts/setup/setup-qa.sh`) e sobe os contêineres Docker na ordem correta.

**Como rodar o deploy:**
```powershell
.\terraform\environments\qa\scripts\deploy-qa.ps1
```

> [!NOTE]
> **Tempo Estimado**: O processo completo (provisionamento + transferência + inicialização) em QA demora aproximadamente **7 minutos**.

---

## Configuração do Data Lake (S3)

As aplicações que consomem o Data Lake utilizam a variável `BUCKET_NAME` no arquivo `.env`. Para o ambiente de QA/Homologação, utilize a camada **Trusted**:

- **BUCKET_NAME**: `solarway-datalake-silver`

Certifique-se de preencher as seguintes variáveis no seu `.env` antes do deploy:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`
- `BUCKET_NAME=solarway-datalake-silver`

---

## Orientações Gerais de Fluxo de Imagens e Build

1. **Build e Push das Imagens**: As imagens deste projeto são hospedadas no **GitHub Packages (GHCR)** sob a organização `projeto-de-extensao-grupo-06`. 
   - Exemplo: `ghcr.io/projeto-de-extensao-grupo-06/springboot-web-backend:latest`.
   - Para que os scripts de setup e composes funcionem, é obrigatório possuir as chaves `GITHUB_USERNAME` e `GITHUB_ACCESS_TOKEN` (com permissão de `read:packages`) configuradas no seu arquivo `.env`.
   - **Nota**: O script de deploy realiza o `docker login` automaticamente no servidor usando essas credenciais.
2. **Setup de Variáveis (`.env`)**: A infraestrutura pulverizada obriga o host operacional a prover os atributos declarados em cada bloco `environment:` dos arquivos localmente por meio de `.env`. 
   - **Importante (AWS)**: Para operações de infraestrutura (Terraform), as credenciais devem ser configuradas via `aws configure` e não pelo `.env`. Consulte a [documentação do Terraform](./terraform/README.md) para detalhes.

## Chaves de Acesso SSH (.pem)
 
 Para que o Terraform consiga realizar o deploy automatizado (provisionamento via SCP e execução remota), é obrigatório possuir uma chave privada no formato .pem na sua conta AWS.
 
 1. **Criação**: No console da AWS Academy / Learner Lab, crie uma chave (Key Pair) do tipo RSA e formato .pem.
 2. **Configuração (.env)**: No seu arquivo `.env`, defina o nome da chave na variável `AWS_KEY_NAME`.
    - Exemplo: `AWS_KEY_NAME=minha-chave`
    - **Padrão**: Caso a variável esteja vazia ou ausente, o sistema assumirá o nome **solarway**.
 3. **Localização**: Salve o arquivo baixado (com o nome definido em `AWS_KEY_NAME` e extensão `.pem`) na raiz deste repositório. O Terraform e os scripts de deploy estão configurados para buscar a chave neste local.
 
 > [!IMPORTANT]
 > Cada membro da equipe deve criar sua própria chave no seu ambiente de teste AWS e garantir que o arquivo .pem correspondente esteja presente localmente antes de rodar o deploy-qa.ps1.
