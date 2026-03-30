#!/bin/bash
# TODO - Testar budega de script
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

# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# if [ -f "$SCRIPT_DIR/../setup-vm.sh" ]; then bash "$SCRIPT_DIR/../setup-vm.sh"; fi

echo "➡️ [PROD-BACKEND] Configurando Código..."
sudo su - "$TARGET_USER" -c "
  BASE_DIR="/tmp/solarway"
  cd "$BASE_DIR"
  echo 'Aguardando Docker daemon...'
  while ! docker info >/dev/null 2>&1; do sleep 2; done

  # Login no GitHub Packages antes de dar pull
  if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "$GITHUB_ACCESS_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
  fi

  # Diferenciação de apps baseada em variável de ambiente (BACKEND_TYPE)
  if [[ "$BACKEND_TYPE" == "monolith" || -z "$BACKEND_TYPE" ]]; then
    echo "➡️ [PROD-BACKEND] Iniciando Monolito..."
    cd services/backend/monolith
    docker compose pull
    docker compose --env-file ../../../.env up -d
    cd ../../..
  fi
  
  if [[ "$BACKEND_TYPE" == "microservice" || -z "$BACKEND_TYPE" ]]; then
    echo "➡️ [PROD-BACKEND] Iniciando Microserviço..."
    cd services/backend/microservice
    docker compose pull
    docker compose --env-file ../../../.env up -d --build
    cd ../../..
  fi
"
echo "✅ [PROD-BACKEND] Provisionamento Finalizado!"
