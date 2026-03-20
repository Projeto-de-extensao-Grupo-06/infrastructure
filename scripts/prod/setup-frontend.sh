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

echo "➡️ [PROD-FRONT] Atualizando S.O..."
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg lsb-release git

echo "➡️ [PROD-FRONT] Instalando Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh && sudo apt-get install -y docker-compose-plugin || true
sudo systemctl enable docker && sudo systemctl start docker

TARGET_USER=${SUDO_USER:-ubuntu}
if ! id "$TARGET_USER" &>/dev/null; then TARGET_USER="root"; fi
sudo usermod -aG docker "$TARGET_USER" || true

echo "➡️ [PROD-FRONT] Configurando Código..."
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

  # Login no GitHub Packages antes de dar pull
  if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "$GITHUB_ACCESS_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
  fi

  cd services/frontend/institucional-website
  docker compose pull
  docker compose --env-file ../../../.env up -d

  cd ../management-system
  docker compose pull
  docker compose --env-file ../../../.env up -d
"
echo "✅ [PROD-FRONT] Provisionamento Finalizado!"
