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

echo "➡️ [PROD-BACKEND] Atualizando S.O..."
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg lsb-release git

echo "➡️ [PROD-BACKEND] Instalando Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh && sudo apt-get install -y docker-compose-plugin || true
sudo systemctl enable docker && sudo systemctl start docker

TARGET_USER=${SUDO_USER:-ubuntu}
if ! id "$TARGET_USER" &>/dev/null; then TARGET_USER="root"; fi
sudo usermod -aG docker "$TARGET_USER" || true

echo "➡️ [PROD-BACKEND] Configurando Código..."
sudo su - "$TARGET_USER" -c "
  cd ~
  if [ ! -d 'docker-composes' ]; then
    git clone https://github.com/Projeto-de-extensao-Grupo-06/docker-composes.git
  else
    cd docker-composes && git pull && cd ..
  fi

  cd docker-composes
  echo 'Aguardando Docker daemon...'
  while ! docker info >/dev/null 2>&1; do sleep 2; done

  cd services/backend/monolith
  docker compose pull
  docker compose --env-file ../../../.env up -d
  
  cd ../microservice
  docker compose pull
  docker compose --env-file ../../../.env up -d --build
"
echo "✅ [PROD-BACKEND] Provisionamento Finalizado!"
