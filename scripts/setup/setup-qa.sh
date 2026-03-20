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

echo "➡️ [Solarway-QA] Instalando Docker Engine..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt-get install -y docker-compose-plugin || true

sudo systemctl enable docker
sudo systemctl start docker

TARGET_USER=${SUDO_USER:-ubuntu}
if ! id "$TARGET_USER" &>/dev/null; then TARGET_USER="root"; fi
sudo usermod -aG docker "$TARGET_USER" || true

echo "✅ [Solarway-QA] Docker instalado. Use o script de deploy local para subir os containers."
