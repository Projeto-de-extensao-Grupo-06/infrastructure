#!/bin/bash
# ==============================================================================
# Ambiente: QA
# Objetivo: Provisionar e iniciar o ambiente via Docker Compose.
# ==============================================================================
set -e

BASE_DIR="/tmp/solarway"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "➡️ [QA] Iniciando provisionamento em $BASE_DIR..."
echo "📂 Estrutura atual em $BASE_DIR:"
ls -R $BASE_DIR | grep ":$" | sed -e 's/:$//' -e 's/[^-][^\/]*\//--/g' -e 's/^/   /'

# O setup-vm.sh deve ter sido executado previamente ou ser chamado aqui
if [ -f "$SCRIPT_DIR/setup-vm.sh" ]; then
    echo "➡️ [QA] Executando configuração de VM (Docker)..."
    bash "$SCRIPT_DIR/setup-vm.sh"
fi

echo "➡️ [QA] Configurando deploy..."
cd "$BASE_DIR"

# Aguarda Docker
echo "⏳ Aguardando Docker daemon..."
while ! sudo docker info >/dev/null 2>&1; do sleep 2; done

# Login no GHCR se as credenciais estiverem no .env
if [ -f "$BASE_DIR/.env" ]; then
    export GITHUB_USERNAME=$(grep GITHUB_USERNAME .env | cut -d'=' -f2 | tr -d '\r')
    export GITHUB_ACCESS_TOKEN=$(grep GITHUB_ACCESS_TOKEN .env | cut -d'=' -f2 | tr -d '\r')
    echo "$GITHUB_ACCESS_TOKEN" | sudo docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
fi

echo "🐳 [QA] Subindo pilha de serviços..."
# Nota: Subindo em ordem: DB -> Backend -> Frontends

echo "➡️ [QA-DB] Iniciando Banco de Dados..."
cd "$BASE_DIR/services/db" && sudo docker compose --env-file ../../.env up -d

echo "➡️ [QA-BACKEND] Iniciando Backend Monolito..."
cd "$BASE_DIR/services/backend/monolith" && sudo docker compose --env-file ../../../.env up -d

echo "➡️ [QA-FRONTEND] Iniciando Management System..."
cd "$BASE_DIR/services/frontend/management-system" && sudo docker compose --env-file ../../../.env up -d

echo "➡️ [QA-FRONTEND] Iniciando Institutional Website..."
cd "$BASE_DIR/services/frontend/institucional-website" && sudo docker compose --env-file ../../../.env up -d

echo "➡️ [QA-PROXY] Iniciando Proxy..."
cd "$BASE_DIR/services/proxy" && sudo docker compose --env-file ../../.env up -d

echo "✅ [QA] Ambiente provisionado com sucesso em http://$(curl -s ifconfig.me)"
