#!/bin/bash
# ==============================================================================
# Solarway - Shared VM Setup Script
# Objetivo: Instalação de Docker e dependências básicas em VMs Ubuntu/Debian.
# ==============================================================================
set -e

# Configura logs
LOG_FILE="/var/log/solarway-setup-vm.log"
if [ "$EUID" -eq 0 ]; then
    exec > >(tee -a "$LOG_FILE"|logger -t solarway-setup -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "➡️ [VM-SETUP] Atualizando repositórios e pacotes básicos..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release git unzip

echo "➡️ [VM-SETUP] Verificando Docker Engine..."
if ! command -v docker &> /dev/null; then
    echo "➡️ [VM-SETUP] Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo apt-get install -y docker-compose-plugin || true
else
    echo "✅ [VM-SETUP] Docker já está instalado."
fi

echo "➡️ [VM-SETUP] Configurando permissões do Docker..."
sudo systemctl enable docker
sudo systemctl start docker

TARGET_USER=${SUDO_USER:-ubuntu}
if ! id "$TARGET_USER" &>/dev/null; then TARGET_USER="root"; fi
sudo usermod -aG docker "$TARGET_USER" || true

echo "✅ [VM-SETUP] Configuração básica da VM finalizada!"
