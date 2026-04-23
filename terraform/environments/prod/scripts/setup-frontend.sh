#!/bin/bash
# ==============================================================================
# Ambiente: PRODUÇÃO
# Camada: Frontend EC2 (Inst. Website e Sistema de Gestão)
# Objetivo: Bootstrap nativo focado nos clientes web escaláveis da AWS
# ==============================================================================
set -e
if [ "$EUID" -eq 0 ]; then
    LOG_FILE="/var/log/solarway-setup.log"
    exec > >(tee -a "$LOG_FILE"|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "[PROD-FRONT] Iniciando Bootstrap..."
echo "Diretorio atual: $(pwd)"
echo "Arquivos em $(pwd):"
ls -la


echo "[PROD-FRONT] Configurando Código..."

BASE_DIR="/tmp/solarway"
if [ ! -d "$BASE_DIR" ]; then
    echo "Erro: Diretório $BASE_DIR nÃ£o encontrado!"
    exit 1
fi

cd "$BASE_DIR"

echo 'Aguardando Docker daemon...'
for i in {1..150}; do
    if sudo docker info >/dev/null 2>&1; then
        echo "Docker pronto!"
        break
    fi
    echo "Aguardando Docker..."
    sleep 2
done

# Login no GitHub Packages (GHCR)
if [ -f .env ]; then
  GITHUB_USERNAME=$(grep GITHUB_USERNAME .env | cut -d'=' -f2 | tr -d '\r')
  GITHUB_ACCESS_TOKEN=$(grep GITHUB_ACCESS_TOKEN .env | cut -d'=' -f2 | tr -d '\r')
  if [ ! -z "$GITHUB_ACCESS_TOKEN" ]; then
    echo "Efetuando login no GHCR..."
    echo "$GITHUB_ACCESS_TOKEN" | sudo docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
  fi
fi

# Diferenciação de apps baseada em variável de ambiente
sudo docker network create solarway_network 2>/dev/null || true
if [[ "$FRONTEND_TYPE" == "institutional" || -z "$FRONTEND_TYPE" ]]; then
    echo "âž¡ï¸ [PROD-FRONT] Iniciando Institucional Website..."
    if [ -d "services/frontend/institucional-website" ]; then
        cd services/frontend/institucional-website
        sudo docker compose pull
        sudo docker compose --env-file ../../../.env up -d
        cd ../../..
    else
        echo "Erro: Diretório services/frontend/institucional-website não encontrado!"
        exit 1
    fi
fi

if [[ "$FRONTEND_TYPE" == "management" || -z "$FRONTEND_TYPE" ]]; then
    echo "[PROD-FRONT] Iniciando Management System..."
    if [ -d "services/frontend/management-system" ]; then
        cd services/frontend/management-system
        sudo docker compose pull
        sudo docker compose --env-file ../../../.env up -d
        cd ../../..
    else
        echo "Erro: Diretório services/frontend/management-system não encontrado!"
        exit 1
    fi
fi

echo "[PROD-FRONT] Provisionamento Finalizado!"
