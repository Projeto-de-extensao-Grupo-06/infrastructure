#!/bin/bash
# TODO - Testar budega de script
# ==============================================================================
# Ambiente: PRODUÇÃO
# Camada: Frontend EC2 (Inst. Website e Sistema de Gestão)
# Objetivo: Bootstrap nativo focado nos clientes web escaláveis da AWS
# ==============================================================================
set -e
if [ "$EUID" -eq 0 ]; then
    exec > >(tee /var/log/user-data-prod-frontend.log|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "➡️ [PROD-FRONT] Configurando Código..."
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

  # Diferenciação de apps baseada em variável de ambiente (FRONTEND_TYPE)
  if [[ "$FRONTEND_TYPE" == "institutional" || -z "$FRONTEND_TYPE" ]]; then
    echo "➡️ [PROD-FRONT] Iniciando Institucional Website..."
    cd services/frontend/institucional-website
    docker compose pull
    docker compose --env-file ../../../.env up -d
    cd ../../..
  fi

  if [[ "$FRONTEND_TYPE" == "management" || -z "$FRONTEND_TYPE" ]]; then
    echo "➡️ [PROD-FRONT] Iniciando Management System..."
    cd services/frontend/management-system
    docker compose pull
    docker compose --env-file ../../../.env up -d
    cd ../../..
  fi
"
echo "✅ [PROD-FRONT] Provisionamento Finalizado!"
