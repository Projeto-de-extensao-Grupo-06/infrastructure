#!/bin/bash
# ==============================================================================
# Ambiente: QA
# Objetivo: Provisionar e iniciar o ambiente via Docker Compose.
# ==============================================================================
set -e

# Se estiver no /tmp, garante permissão de execução (caso precise ser chamado via Terraform)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "➡️ [QA] Iniciando provisionamento do ambiente..."

# O setup-vm.sh deve ter sido executado previamente ou ser chamado aqui
if [ -f "$SCRIPT_DIR/setup-vm.sh" ]; then
    bash "$SCRIPT_DIR/setup-vm.sh"
fi

echo "➡️ [QA] Configurando deploy..."
cd "$SCRIPT_DIR/.." # Sobe para a pasta docker-composes

# Aguarda Docker
while ! sudo docker info >/dev/null 2>&1; do echo "Aguardando Docker..."; sleep 2; done

# Login no GHCR se as credenciais estiverem no .env
if [ -f .env ]; then
    export GITHUB_USERNAME=$(grep GITHUB_USERNAME .env | cut -d'=' -f2 | tr -d '\r')
    export GITHUB_ACCESS_TOKEN=$(grep GITHUB_ACCESS_TOKEN .env | cut -d'=' -f2 | tr -d '\r')
    echo "$GITHUB_ACCESS_TOKEN" | sudo docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
fi

echo "🐳 [QA] Subindo pilha de serviços..."
# Nota: Ajustado para subir tudo em ordem
cd services/db && sudo docker compose --env-file ../../.env up -d
sleep 5
cd ../backend/monolith && sudo docker compose --env-file ../../../.env up -d
cd ../../frontend/management-system && sudo docker compose --env-file ../../../.env up -d
cd ../institucional-website && sudo docker compose --env-file ../../../.env up -d

echo "✅ [QA] Ambiente provisionado com sucesso!"
