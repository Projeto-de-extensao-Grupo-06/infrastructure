# Módulo de Automação (n8n + WAHA)

Este repositório contém a stack responsável pelas automações do WhatsApp integradas à plataforma de inteligência artificial corporativa.

A stack utiliza:

- **n8n**: Orquestrador visual de fluxos de integração.
- **WAHA**: Interface de Programação de Aplicação (API) para o WhatsApp.
- **Redis**: Sistema de armazenamento em memória voltado para gestão de sessões, mensageria e controle de requisições.

---

## 1. Configuração de Ambiente

As seguintes variáveis de ambiente estão declaradas no `docker-compose.yml`:

- `BACKEND_API_URL`: Mapeada para `http://host.docker.internal:8000`. Permite que o n8n se comunique com a API REST do backend (Spring Boot).
- `BOT_SECRET`: Chave criptográfica simétrica para autenticação nos endpoints do backend.

**Atenção:** A inicialização desta stack pressupõe que a stack **`apps`** esteja ativa.

```bash
docker-compose up -d
```

---

## 2. Configuração do n8n

Com os serviços ativos, acessar a interface do n8n via: `http://localhost:5678`.

O setup inicial exige as seguintes configurações:

### I. Importação de Workflows

1. Navegue até a opção de adicionar novo fluxo (Add Workflow).
2. Acesse as opções de configuração globais do fluxo e selecione **Import from File**.
3. Selecione o arquivo `whatsapp-bot-ai.json` (ou sua versão base) contido no diretório `bot`.
4. Mude o status do Workflow para **Active**.

### II. Mapeamento de Credenciais (Credentials)

Os fluxos importados possuem dependências de serviços cujo acesso requer autenticação explícita:

1. **Conta Redis:**
   - Host: `bot-redis`
   - Port: `6379`
   - Password: `default`

2. **Google Gemini (PaLM) API:**
   - Adicione sua respectiva API Key do Google Gemini, essencial para operações de NLP, extração de entidades e tomada de decisão sobre acionamento de ferramentas.

3. **Conta WAHA:**
   - URL Base: `http://waha:3000` (acessível via network `bot_network`)
   - Configure credenciais básicas para comunicação entre n8n e WAHA.

### III. Provisão de Sessão no WhatsApp (WAHA)

Para associar um terminal de comunicação ativo:

1. Acesse o dashboard gerencial do WAHA: `http://localhost:3000/dashboard`
2. Inicialize a sessão categorizada como `default` para alinhamento com a lógica orquestrada no n8n.
3. Proceda com o escaneamento do QR Code gerado pelo sistema.
