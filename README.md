# Solarize - Configuração dos Projetos via Docker

Este repositório contém os arquivos orquestradores (docker-compose) divididos em duas partes principais: **Storage** (Bancos de Dados) e **Bot** (Backend, WhatsApp, e Automações com n8n).

Por mais que o storage seja simples, é **obrigatório** rodá-lo primeiro, pois o ambiente do bot depende da rede e do banco de dados criados nele.

---

## 1. Subindo o Storage (Banco de Dados e Redis Principal)

O ambiente de storage é essencial para fornecer o banco de dados MySQL para o backend.

1. Navegue até a pasta do storage:
   ```bash
   cd dev/storage
   ```
2. Inicie os containers em segundo plano:
   ```bash
   docker-compose up -d
   ```
*(Nota: Isso criará a rede `storage_default`, necessária para a comunicação do backend com o MySQL.)*

---

## 2. Configurando e Subindo o Bot (Backend + n8n + Waha)

Neste passo, iremos "buildar" o container do backend, subir os serviços do bot e configurar as credenciais dentro do **n8n**.

1. Volte para a raiz e navegue até a pasta do bot:
   ```bash
   cd ../../bot
   ```
2. Faça o build (para o backend) e suba todos os containers:
   ```bash
   docker-compose up -d --build
   ```

### 3. Configurações dentro do n8n

Após o comando anterior, todos os serviços estarão online. O n8n estará acessível em: `http://localhost:5678`.

Siga os seguintes passos para conectar os serviços no n8n:

1. Acesse `http://localhost:5678` no seu navegador.
2. **Importar os Workflows:** Importe os arquivos JSON de exemplo que estão na pasta `bot` (ex: `whatsapp-bot.json` e `whatsapp-bot-ai.json`).
3. **Settar Conta Redis:**
   - Vá até a área de Credentials / Conexões no n8n.
   - Crie uma credencial para o nó do Redis.
   - Use os dados conforme definido no docker-compose do bot:
     - **Host:** `redis`
     - **Port:** `6379`
     - **Password:** `default`
4. **Settar Chaves de API Gemini:**
   - Da mesma forma nas Credentials, crie ou edite a credencial responsável pelo Google Gemini.
   - Insira a sua *API Key* do Gemini correspondente.
5. **Configurações Adicionais n8n:**
   - Caso possua nós de comunicação com o WhatsApp (Waha), certifique-se de que a URL interna `http://waha:3000` está configurada corretamente nos nós HTTP do n8n.
   
---

## Resumo dos Serviços

- **MySQL:** `localhost:3307` (storage)
- **Redis (Multidb):** `localhost:6379` (storage)
- **Redis (Bot):** Interno para n8n `redis:6379` (bot)
- **Backend Service:** `localhost:8000` (bot)
- **Waha (WhatsApp Bot):** `localhost:3000` (bot)
- **n8n (Workflows):** `localhost:5678` (bot)