# Docker Composes - Infraestrutura

Bem-vindo ao repositório de infraestrutura baseada em Docker Compose do Projeto de Extensão Solarize / Sptech.

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
.\scripts\setup-local.ps1
```

**Linux/Mac (Bash WSL):**
```bash
./scripts/setup-local.sh
```

Isso subirá de uma só vez o MySQL, o Redis-Multidb, o Monolito do Spring Boot, os contêineres do Sistema de Gerenciamento, do Site e dos serviços nativos do WhatsApp IA.

---

## Deployments e Ambientes Segregados

Seguindo fidedignamente a arquitetura pulverizada da nuvem (onde sub-redes isolam frontends, backends e workers), a pasta `scripts/` detém gatilhos específicos de *User Data* para VMs isoladas:

- **`scripts/setup-qa.sh`**: Instala a infra inteira em uma única máquina Linux para rodadas de testes integrados.
- **`scripts/prod/setup-[camada].sh`**: Cada arquivo deste atua nativamente ativando só a camada designada (`db`, `backend`, `frontend`, `bot`), poupando espaço nas instâncias e limitando a esteira apenas ao que a VM foi desenhada para processar.

---

## Redes e Comunicação (Networks)

Para garantir conectividade direta e resolução de DNS interna nativa (abandonando a dependência legada e instável de acessos via IP ou pelo `host.docker.internal`), todos os módulos foram uniformizados para operar sob a mesma infraestrutura de conectividade.

- **`solarize_network`**: Rede em ponte (bridge) central para comunicação cruzada unificada (Backend ↔ Frontend ↔ Bot). 
  - O **`backend/monolith/docker-compose.yml`** assume o papel de hospedar e construir a definição original da rede. Portanto, a orientação é sempre **iniciar o serviço do Backend primeiro**.
  - Todos os demais módulos atuam como parasitas na rede e se anexam em modo leitura (`external: true`).
- **`storage_network`**: Rede focada ao tráfego de persistências cruas atrelada ao Data Lake e microsserviços pesados adjacentes.

**Resolução por Nomes**: Em decorrência do alinhamento, os serviços dentro da *solarize_network* atingem uns aos outros pelo `container_name`. Por exemplo, o N8N conecta-se ao servidor Spring pela URL dinâmica: `http://backend-service:8000`.
---

## Proxy e Segurança (Load Balancer SSL)

Para processar comunicações TLS/SSL e atuar como Gateway HTTP/HTTPS centralizado do produto, o diretório **`proxy/`** oferece um contêiner Nginx roteado com Certbot (Let's Encrypt).

- **Estratégia Nuvem**: O proxy requer leitura física de certificados. Em domínios remotos cloud, nunca inicie direto pelo `docker-compose up -d`. Ao invés disso, execute o utilitário embarcado `./init-letsencrypt.sh`, após pré-configurar os domínios no `config/app.conf`. 
- **Homologação Local**: Para debug de rotas via localhost, emita certificados autoassinados (self-signed key e crt) descartáveis e altere as chaves de rede (`hosts` OS) apontando ao local.

---

## Infraestrutura como Código - AWS (Terraform)

No repertório **`terraform/`**, residem os scripts padronizados focados em alocação de EC2, S3 e VPCs. Seu workflow modular foi pensado com estratégias de escala isoladas por ambiente:

- **Ambiente DEV (`environments/dev`)**: VPC desenhada em Single-AZ. Sobe máquinas menos robustas aglomerando todas as instâncias e redes localmente. Usada primariamente como Sandbox com as três fases do datalake simplificadas.
- **Ambiente PROD (`environments/prod`)**: Topologia de Alta Disponibilidade. Provisiona Sub-redes Públicas (Proxy) e Privadas, isolando rigidamente Frontend, Backend, Automations e Datastore Persistence.

Todo provisionamento ocorre através do CLI: `terraform init`, `terraform plan` e consequente aplicação (`terraform apply`).

---

## Orientações Gerais de Fluxo de Imagens e Build

1. **Build e Push das Imagens**: Nos projetos originais de código aberto (`springboot`, `management-system`, etc.), as compilações manuais `docker build` são seguidas por um envio logístico (Push Registry) a centralizadoras como o Docker Hub. É a partir do registro publicado que os `docker-compose.yml` da pasta infra adquirem as builds para subir e instanciar aplicações instantaneamente na nuvem sem requerer node_modules ou gradle compilando fisicamente no host operacional.
2. **Setup de Variáveis (`.env`)**: A infraestrutura pulverizada obriga o host operacional a prover os atributos declarados em cada bloco `environment:` dos arquivos localmente por meio de `.env` que, repete-se como regra, nunca devem ser versionados via Git.
