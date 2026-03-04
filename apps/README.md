# Apps Docker Compose

Este módulo orquestra a camada de aplicações do projeto, englobando o backend (Spring Boot) e os frontends (React/Vite).

## Comandos Úteis

Para construir as imagens e iniciar a execução dos containers em background:

```bash
docker-compose up -d --build
```

Para monitorar os logs de um serviço específico (por exemplo, o frontend):

```bash
docker-compose logs -f frontend-service
```

## Acesso e Validação dos Serviços

Após a integridade de todos os containers via `docker-compose ps`:

- **Frontend (Management System):** Disponível em `http://localhost:8080`. O build é realizado via Vite e servido estaticamente pelo Node.js (`serve`) na porta interna 3000, mapeada no host para a 8080.
- **Frontend (Institutional Website):** Disponível em `http://localhost:8081`. Operação análoga ao container anterior, compilando via Vite e utilizando a porta interna 3000, mapeada no host para a 8081.
- **Backend (Spring Boot):** Disponível em `http://localhost:8000`.

**Atenção:** É estritamente obrigatório que a stack `storage` (MySQL e Redis) esteja operacional **antes** da inicialização da stack de apps. O serviço `backend-service` exige conexão efetiva com `mysql-db` na rede `storage_network` durante seu boot. O descumprimento desta regra gerará exceptions de conexão.
