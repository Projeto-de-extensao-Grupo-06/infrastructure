# Apps Docker Compose

Este docker-compose gerencia o backend (Spring Boot) e o frontend (React/Vite) do projeto.

## Comandos Úteis

Para construir as imagens (incluindo o novo Dockerfile do frontend) e subir os containers:

```bash
docker-compose up -d --build
```

Para verificar os logs de um serviço específico (ex: frontend):

```bash
docker-compose logs -f frontend-service
```

## Acessando os Serviços (Testes)

Após os containers subirem com sucesso (`docker-compose ps` para checar):

- **Frontend (Management System):** Acesse `http://localhost:8080`. Este container compila o código via Vite e usa um servidor HTTP simples (`serve` do Node.js) para servir os arquivos estáticos na porta 3000, hospedada na 8080.
- **Frontend (Institutional Website):** Acesse `http://localhost:8081`. Similar ao management-system, usa Node para compilar via Vite e servir estaticamente na porta 3000 interna, mapeada para a 8081 externa.
- **Backend (Spring Boot):** Acesse `http://localhost:8000` (ex: `http://localhost:8000/api/sua-rota-de-teste` ou Swagger caso ativo).

> **Atenção:** Assegure-se de que a stack `storage` (MySQL e Redis) está rodando **antes** de subir esta stack, pois o `backend-service` precisa se conectar ao banco de dados `mysql-db` na rede `storage_network`.
