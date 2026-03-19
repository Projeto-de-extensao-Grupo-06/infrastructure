# Banco de Dados da Aplicação (Storage Stack)

Esta stack contém os componentes fundamentais de armazenamento persistente e cache que as outras partes do sistema (como a `apps` e a `bot`) precisam para funcionar corretamente.

A stack utiliza:

- **MySQL (8.0)**: Banco de dados relacional principal da aplicação `backend-service`.
- **Redis (Multidb)**: Servidor de cache e filas provido para o backend.

---

## Ordem de Execução

**ATENÇÃO:** É mandatório iniciar os containers desta pasta `services/db` (storage) antes de qualquer outra stack (`backend`, `frontend` ou `bot`).

A justificativa técnica para isso é que este `docker-compose.yml` expõe e cria nativamente a rede Docker `storage_network`. O container do Backend Spring Boot requer conectividade ativa com a base de dados (`mysql-db`) e o cache corporativo (`redis-multidb`) por meio desta rede.

## Como Executar

1. Navegue até o diretório `services/db`.
2. Execute o comando para subir as instâncias de banco de dados em segundo plano:

   ```bash
   docker-compose up -d
   ```

3. Verifique o status (healthcheck) dos serviços através do comando `docker-compose ps`.

Após a validação de integridade do MySQL e Redis, o ambiente estará apto para a execução do diretório **`services/backend/monolith`**.

---

## Codificação UTF-8 e Scripts de Inicialização

O container do MySQL (`mysql-db`) foi nativamente adaptado via paramentos de boot do Compose para adotar UTF-8 (`utf8mb4_unicode_ci`). Isto previne nativamente que acentuações da língua portuguesa tornem-se caracteres corrompidos na aplicação Java.

A arquitetura também utiliza o mapeamento nativo de volumes via pasta `mysql-init/`. O arquivo `init.sql` injeta tabelas essenciais (como as de Oçamento e Permissões) com blocos recheados de dados mockados (com `INSERT IGNORE`). **Atenção:** Estes dados são escritos permanentemente no volume persistido; e só rodarão como *seed* inicial em um banco recém-criado ou após um expurgo limpo (`docker-compose down -v`).
