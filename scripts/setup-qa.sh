#!/bin/bash
# TODO - Testar budega de script
# ==============================================================================
# Ambiente: QA
# Objetivo: Provisionar uma instância EC2 única rodando o ambiente completo.
# Execuçao Automática: AWS EC2 User Data
# ==============================================================================
set -e

# Configura logs do User Data
if [ "$EUID" -eq 0 ]; then
    exec > >(tee /var/log/user-data-setup-qa.log|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "➡️ [QA] Atualizando e instalando pré-requisitos..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release git

echo "➡️ [QA] Instalando Docker Engine..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt-get install -y docker-compose-plugin || true

sudo systemctl enable docker
sudo systemctl start docker

TARGET_USER=${SUDO_USER:-ubuntu}
if ! id "$TARGET_USER" &>/dev/null; then TARGET_USER="root"; fi
sudo usermod -aG docker "$TARGET_USER" || true

echo "➡️ [QA] Clonando o Repositório de Composes..."
sudo su - "$TARGET_USER" -c "
  cd ~
  if [ ! -d 'docker-composes' ]; then
    git clone https://github.com/Projeto-de-extensao-Grupo-06/docker-composes.git
  else
    cd docker-composes
    git pull
    cd ..
  fi

  cd docker-composes

  echo '➡️ [QA] Inicializando a base de dados...'
  cd services/db
  docker compose --env-file ../../.env up -d

  echo '➡️ [QA] Aguardando o banco respirar...'
  sleep 15

  echo '➡️ [QA] Subindo Backends...'
  cd ../backend/monolith
  docker compose --env-file ../../../.env up -d
  cd ../microservice
  docker compose --env-file ../../../.env up -d --build

  echo '➡️ [QA] Subindo Frontends...'
  cd ../../frontend/management-system
  docker compose --env-file ../../../.env up -d
  cd ../institucional-website
  docker compose --env-file ../../../.env up -d

  echo '➡️ [QA] Subindo Serviços de Bot...'
  cd ../../bot
  docker compose --env-file ../../.env up -d

  echo '✅ [QA] Ambiente Provisionado com Sucesso!'
"
