#!/bin/bash
# ==============================================================================
# Ambiente: PRODUÇÃO
# Camada: Backend EC2 (Monolito e Microserviços)
# Objetivo: Bootstrap nativo focado no backend isolado na AWS
# ==============================================================================
set -e
if [ "$EUID" -eq 0 ]; then
    exec > >(tee /var/log/user-data-prod-backend.log|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "➡️ [PROD-BACKEND] Configurando Código..."

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

# Diferenciação de apps baseada em variável de ambiente (BACKEND_TYPE)
if [[ "$BACKEND_TYPE" == "monolith" || -z "$BACKEND_TYPE" ]]; then
    echo "➡️ [PROD-BACKEND] Iniciando Monolito..."
    if [ -d "services/backend/monolith" ]; then
        cd services/backend/monolith
        sudo docker compose pull
        sudo docker compose --env-file ../../../.env up -d
        cd ../../..
    else
        echo "❌ Erro: Diretório services/backend/monolith não encontrado!"
        exit 1
    fi
fi

if [[ "$BACKEND_TYPE" == "microservice" || -z "$BACKEND_TYPE" ]]; then
    echo "➡️ [PROD-BACKEND] Iniciando Microserviço..."
    if [ -d "services/backend/microservice" ]; then
        cd services/backend/microservice
        sudo docker compose pull
        sudo docker compose --env-file ../../.env up -d --build
        cd ../../..
    else
        echo "❌ Erro: Diretório services/backend/microservice não encontrado!"
        exit 1
    fi
fi

echo "✅ [PROD-BACKEND] Provisionamento Finalizado!"
