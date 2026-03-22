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

---

## Início Rápido (Execução Local Completa)

Para testes, homologações ou desenvolvimento contínuo local, foram providenciados scripts abstraem a complexidade do cluster e obedecem rigidamente à ordem cronológica de inicializações (Banco de Dados Primário ➔ Backend Originador da Rede ➔ Interfaces e Bots).

Abra um terminal na **raiz** deste diretório e execute o script apropriado ao seu ecossistema:

**Windows (PowerShell):**
```powershell
.\scripts\setup\setup-local.ps1
```

**Linux/Mac (Bash WSL):**
```bash
./scripts/setup/setup-local.sh
```

Isso subirá de uma só vez o MySQL, o Redis-Multidb, o Monolito do Spring Boot, os contêineres do Sistema de Gerenciamento, do Site e dos serviços nativos do WhatsApp IA.

---

## Deployments e Ambientes Segregados

Seguindo fidedignamente a arquitetura pulverizada da nuvem (onde sub-redes isolam frontends, backends e workers), a pasta `scripts/` detém gatilhos específicos de *User Data* para VMs isoladas:

- **`scripts/setup/setup-qa.sh`**: Instala a infra inteira em uma única máquina Linux para rodadas de testes integrados.
- **`scripts/prod/setup-[camada].sh`**: Cada arquivo deste atua nativamente ativando só a camada designada (`db`, `backend`, `frontend`, `bot`). 
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

| URL | Destino |
|-----|---------|
| `http://localhost/` | Management System |
| `http://localhost:81/` | Institucional Website |
| `http://localhost/health` | Healthcheck do proxy |

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
.\scripts\deploy\deploy-qa.ps1
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
2. **Nome da Chave**: O nome da chave deve ser **solarway**.
3. **Localização**: Salve o arquivo baixado (solarway.pem) na raiz deste repositório. O Terraform e os scripts de deploy estão configurados para buscar a chave neste local.

> [!IMPORTANT]
> Cada membro da equipe deve criar sua própria chave no seu ambiente de teste AWS e garantir que o arquivo solarway.pem esteja presente localmente antes de rodar o deploy-qa.ps1.
