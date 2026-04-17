#!/bin/bash
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

echo "➡️ [PROD-DB] Provisionando com Docker..."

BASE_DIR="/tmp/solarway"
if [ ! -d "$BASE_DIR" ]; then
    echo "❌ Erro: Diretório $BASE_DIR não encontrado!"
    exit 1
fi

cd "$BASE_DIR"

echo 'Aguardando Docker daemon...'
for i in {1..30}; do
    if sudo docker info >/dev/null 2>&1; then
        echo "✅ Docker está pronto!"
        break
    fi
    echo "Aguardando Docker..."
    sleep 2
done

# Login no GitHub Packages (GHCR)
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
  if [ ! -z "$GITHUB_ACCESS_TOKEN" ]; then
    echo "Efetuando login no GHCR..."
    echo "$GITHUB_ACCESS_TOKEN" | sudo docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
  fi
fi

if [ -d "services/db" ]; then
    cd services/db
    echo "➡️ [PROD-DB] Pulling images..."
    sudo docker compose pull
    echo "➡️ [PROD-DB] Starting containers..."
    sudo docker compose --env-file ../../.env up -d
else
    echo "❌ Erro: Diretório services/db não encontrado!"
    exit 1
fi

echo "✅ [PROD-DB] Provisionamento Finalizado!"

# Healthcheck
sleep 15
if ! nc -z localhost 3306; then
  echo "❌ MySQL nao responde"
  exit 1
fi

if ! nc -z localhost 6379; then
  echo "❌ Redis nao responde"
  exit 1
fi

echo "✅ Database healthcheck OK"
