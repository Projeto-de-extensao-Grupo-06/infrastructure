# Infraestrutura de Backend

Este diretório contém a infraestrutura essencial para os serviços de processamento de regras de negócios da aplicação. Após a pulverização dos composes, a arquitetura distingue operações através de instâncias distintas: monolítica e microserviços.

## Estrutura Atual

- **`monolith/`**: Centraliza o core backend em Spring Boot. O manifesto contido sob esta pasta puxa a versão compilada via imagem e estabelece o elo dele com portas, redes e variáveis sensíveis.
- **`microservice/`**: Configurações adicionais de serviços específicos (ex: `schedule-notification`), podendo ser acompanhados de seus próprios datastores (como MySQL para agendamentos).

---

## Como Fazer Build / Atualizar Imagens (GitHub Packages)

As imagens deste serviço são hospedadas no **GitHub Container Registry (GHCR)**.

1. **Autenticação**:
   Antes de qualquer operação, realize o login no registro da organização:
   ```bash
   echo $GITHUB_ACCESS_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
   ```

2. **Build e Tag**:
   Acesse o repositório de código fonte do backend e execute:
   ```bash
   docker build -t ghcr.io/projeto-de-extensao-grupo-06/springboot-web-backend:latest .
   ```

3. **Push**:
   ```bash
   docker push ghcr.io/projeto-de-extensao-grupo-06/springboot-web-backend:latest
   ```

*(Nota: no caso de microserviços que declarem a propriedade `build: .` em seu manifesto interno, o próprio sub-diretório de infra já agirá como construtor caso os artefatos de build sejam dispostos).*

---

## Variáveis de Ambiente

> Todas as variáveis abaixo devem estar no `.env` na raiz do repositório de infra. Consulte o [VARIABLES_REFERENCE.md](../../docs/VARIABLES_REFERENCE.md) para detalhes completos.

### Monolito (`monolith/docker-compose.yml`)

| Variável | Obrig. | Descrição |
|----------|:------:|-----------|
| `DB_USERNAME` | 🔴 | Usuário do MySQL |
| `DB_PASSWORD` | 🔴 | Senha do MySQL |
| `EMAIL` | 🔴 | E-mail remetente de notificações |
| `EMAIL_PASSWORD` | 🔴 | Senha/App Password do e-mail (Gmail) |
| `BOT_SECRET` | 🔴 | Chave simétrica para autenticar o bot |
| `BUCKET_NAME` | 🔴 | Nome do bucket S3 do Data Lake |
| `AWS_ACCESS_KEY_ID` | 🔴 | Credencial de sessão AWS |
| `AWS_SECRET_ACCESS_KEY` | 🔴 | Credencial de sessão AWS |
| `AWS_SESSION_TOKEN` | 🟡 | Token de sessão AWS (Academy) |
| `PORT_BACKEND_MONOLITH` | 🟢 | Porta externa (padrão: `8000`) |

### Microserviço (`microservice/docker-compose.yml`)

| Variável | Obrig. | Descrição |
|----------|:------:|-----------|
| `DB_PASSWORD` | 🔴 | Senha do MySQL isolado do microserviço |
| `PORT_BACKEND_MICROSERVICE` | 🟢 | Porta externa (padrão: `8082`) |
| `PORT_MICROSERVICE_DB` | 🟢 | Porta do MySQL do microserviço (padrão: `3306`) |

---

## Iniciando

Uma vez que as imagens estão dispostas remota ou localmente, basta adentrar ao respectivo diretório do sub-módulo que se deseja iniciar e executar:

### Iniciando o Monolito
```bash
cd monolith
docker compose up -d
```

### Iniciando Microserviços (Ex: schedule-notification)
```bash
cd microservice
docker compose up -d --build
```
> **Nota de Build**: O manifesto apontará o contexto de compilação relativo (`build: ../../../../schedule-notification`) localizando o repositório-irmão do código fonte fora deste repositório de infra. Para que a compilação local da imagem do microserviço funcione, ele precisa encontrar e ler um `.env` existente nesse repositório fonte.

Em ambos cenários o app tenta participar de instâncias como `storage_network` ou `solarway_network`. Repare que o `monolith` constrói a bridge de comunicação primária *solarway_network*. (Se obtiver erro por pontes externas remanescentes, exija a criação delas previamente no host `docker network create [nome]`).
