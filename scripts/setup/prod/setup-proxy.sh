#!/bin/bash
# TODO - Testar budega de script
# ==============================================================================
# Ambiente: PRODUÇÃO
# Camada: Nginx Proxy EC2
# Objetivo: Bootstrap nativo focado no Proxy reverso central da AWS
# ==============================================================================
set -e
if [ "$EUID" -eq 0 ]; then
    exec > >(tee /var/log/user-data-prod-proxy.log|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "➡️ [PROD-PROXY] Configurando Código..."
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

  cd proxy
  docker compose pull
  docker compose --env-file ../.env up -d
"
echo "✅ [PROD-PROXY] Provisionamento Finalizado!"
