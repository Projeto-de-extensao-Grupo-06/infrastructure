#!/bin/bash
# ==============================================================================
# Ambiente: PRODUÃ‡ÃƒO
# Camada: Backend EC2 (Monolito e MicroserviÃ§os)
# Objetivo: Bootstrap nativo focado no backend isolado na AWS
# ==============================================================================
set -e
if [ "$EUID" -eq 0 ]; then
    LOG_FILE="/var/log/solarway-setup.log"
    exec > >(tee -a "$LOG_FILE"|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "âž¡ï¸ [PROD-BACKEND] Iniciando Bootstrap..."
echo "ðŸ“‚ Diretorio atual: $(pwd)"
echo "ðŸ“„ Arquivos em $(pwd):"
ls -la


BASE_DIR="/tmp/solarway"
if [ ! -d "$BASE_DIR" ]; then
    echo "âŒ Erro: Diretório $BASE_DIR nÃ£o encontrado!"
    exit 1
fi

cd "$BASE_DIR"

echo 'Aguardando Docker daemon...'
for i in {1..150}; do
    if sudo docker info >/dev/null 2>&1; then
        echo "âœ… Docker estÃ¡ pronto!"
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
sudo docker network create solarway_network 2>/dev/null || true
if [[ "$BACKEND_TYPE" == "monolith" || -z "$BACKEND_TYPE" ]]; then
    echo "âž¡ï¸ [PROD-BACKEND] Iniciando Monolito..."
    if [ -d "services/backend/monolith" ]; then
        cd services/backend/monolith
        sudo docker compose pull
        sudo docker compose --env-file ../../../.env up -d
        cd ../../..
    else
        echo "âŒ Erro: Diretório services/backend/monolith nÃ£o encontrado!"
        exit 1
    fi
fi

if [[ "$BACKEND_TYPE" == "microservice" || -z "$BACKEND_TYPE" ]]; then
    echo "âž¡ï¸ [PROD-BACKEND] Iniciando MicroserviÃ§o..."
    if [ -d "services/backend/microservice" ]; then
        cd services/backend/microservice
        sudo docker compose pull
        sudo docker compose --env-file ../../.env up -d --build
        cd ../../..
    else
        echo "âŒ Erro: Diretório services/backend/microservice nÃ£o encontrado!"
        exit 1
    fi
fi

echo "âœ… [PROD-BACKEND] Provisionamento Finalizado!"
