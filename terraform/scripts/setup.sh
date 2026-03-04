#!/bin/bash
# ==============================================================================
# Instalação do Docker e Preparação do Ambiente 
# (Suporta execução manual ou via EC2 User Data)
# ==============================================================================

set -e

# Configura logs se executado como root (ex: AWS User Data)
if [ "$EUID" -eq 0 ]; then
    exec > >(tee /var/log/user-data-setup.log|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "➡️ Iniciando atualização do sistema e instalação de pré-requisitos..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release git

echo "➡️ Instalando o Docker usando o script oficial via curl..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

echo "➡️ Instalando docker-compose-plugin adicional (se faltante)..."
sudo apt-get install -y docker-compose-plugin || true

echo "➡️ Habilitando o Docker para iniciar junto com o sistema..."
sudo systemctl enable docker || true
sudo systemctl start docker || true

# ==============================================================================
# Configuração de Permissões e Usuário Alvo
# ==============================================================================
# Identifica o usuário correto (ubuntu na EC2, ou o usuário atual na máquina local)
if [ "$EUID" -eq 0 ]; then
    TARGET_USER=${SUDO_USER:-ubuntu}
    if ! id "$TARGET_USER" &>/dev/null; then TARGET_USER="root"; fi
else
    TARGET_USER=$USER
fi

echo "➡️ Adicionando o usuário '$TARGET_USER' ao grupo 'docker'..."
sudo usermod -aG docker "$TARGET_USER" || true

echo "if ! groups | grep -q docker; then newgrp docker; fi" | sudo tee -a "/home/$TARGET_USER/.bashrc" > /dev/null

# ==============================================================================
# Download do Repositório (Composes) e Execução
# ==============================================================================
echo "➡️ Configurando o projeto para o usuário $TARGET_USER..."

# Utilizamos o 'su' para rodar os próximos comandos com o usuário e grupo corretos
sudo su - "$TARGET_USER" -c "
  echo 'Aguardando o daemon do Docker iniciar...'
  while ! docker info >/dev/null 2>&1; do
    sleep 2
  done

  echo '➡️ Clonando repositório de docker-composes...'
  cd ~
  if [ ! -d 'docker-composes' ]; then
    git clone https://github.com/Projeto-de-extensao-Grupo-06/docker-composes.git
    echo '✅ Repositório clonado com sucesso.'
  else
    echo '⚠️  O diretório docker-composes já existe. Atualizando com git pull...'
    cd docker-composes
    git pull
    cd ..
  fi

  echo '➡️ Baixando imagens e iniciando os containers (Storage, Proxy, Bot, Apps)...'
  cd docker-composes
  for dir in storage proxy bot apps; do
    if [ -d \"\$dir\" ]; then
      echo \"➡️ Iniciando container(s) em \$dir...\"
      cd \"\$dir\"
      docker compose pull
      docker compose up -d
      cd ..
    fi
  done
"

echo "=============================================================================="
echo "✅ Instalação concluída e containers iniciados!"
if [ "$EUID" -ne 0 ]; then
echo ""
echo "⚠️  IMPORTANTE: Para usar comandos manuais 'docker' neste terminal sem sudo,"
echo "rode o comando abaixo nesta sessão para aplicar o grupo imediatamente:"
echo ""
echo "    newgrp docker"
echo ""
echo "Você também pode simplesmente fechar este terminal e abrir um novo."
fi
echo "=============================================================================="
