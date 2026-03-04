# Banco de Dados da Aplicação (Storage Stack)

Esta stack contém os componentes fundamentais de armazenamento persistente e cache que as outras partes do sistema (como a `apps` e a `bot`) precisam para funcionar corretamente.

A stack utiliza:

- **MySQL (8.0)**: Banco de dados relacional principal da aplicação `backend-service`.
- **Redis (Multidb)**: Servidor de cache e filas provido para o backend.

---

## Ordem de Execução

**ATENÇÃO:** É mandatório iniciar os containers desta pasta `storage` antes de qualquer outra stack (`apps` ou `bot`).

A justificativa técnica para isso é que este `docker-compose.yml` expõe e cria nativamente a rede Docker `storage_network`. O container do Backend Spring Boot (localizado em `apps`) requer conectividade ativa com o container `mysql-db` atrelado a esta rede. A ausência prévia da rede resultará em falha na inicialização da stack de aplicações.

## Como Executar

1. Navegue até o diretório `storage`.
2. Execute o comando para subir as instâncias de banco de dados em segundo plano:

   ```bash
   docker-compose up -d
   ```

3. Verifique o status (healthcheck) dos serviços através do comando `docker-compose ps`.

Após a validação de integridade do MySQL e Redis, o ambiente estará apto para a execução do diretório **`apps`**.
