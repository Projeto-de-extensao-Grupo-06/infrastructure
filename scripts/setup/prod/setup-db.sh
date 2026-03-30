#!/bin/bash
# TODO - Testar budega de script
# ==============================================================================
# Ambiente: PRODUÇÃO
# Camada: Database EC2
# Objetivo: Bootstrap nativo focado em banco de dados isolado no AWS
# ==============================================================================
set -e
if [ "$EUID" -eq 0 ]; then
    exec > >(tee /var/log/user-data-prod-db.log|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "➡️ [PROD-DB] Configurando Código..."
sudo su - "$TARGET_USER" -c "
  BASE_DIR="/tmp/solarway"
  cd "$BASE_DIR"
  echo 'Aguardando Docker daemon...'
  while ! docker info >/dev/null 2>&1; do sleep 2; done

  # Injeção via AWS Parameter Store, Secrets Manager, etc., pode substituir o step abaixo.
  # Assumindo que haverá injeção ambiental primária para a camada:
  cd services/db
  docker compose pull
  docker compose --env-file ../../.env up -d
"
echo "✅ [PROD-DB] Provisionamento Finalizado!"

# Healthcheck
sleep 10
if ! nc -z localhost 3306; then
  echo "❌ MySQL nao responde"
  exit 1
fi

if ! nc -z localhost 6379; then
  echo "❌ Redis nao responde"
  exit 1
fi

echo "✅ Database healthcheck OK"
