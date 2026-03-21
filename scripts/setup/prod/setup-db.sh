#!/bin/bash
# TODO - Testar budega de script
# ==============================================================================
# Ambiente: PRODUÇÃO
# Camada: Database EC2
# Objetivo: Bootstrap nativo focado em banco de dados isolado no AWS
# ==============================================================================
set -e
if [ "$EUID" -eq 0 ]; then
    exec > >(tee /var/log/user-data-prod-db.log|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "➡️ [PROD-DB] Configurando Código..."
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

  # Injeção via AWS Parameter Store, Secrets Manager, etc., pode substituir o step abaixo.
  # Assumindo que haverá injeção ambiental primária para a camada:
  cd services/db
  docker compose pull
  docker compose --env-file ../../.env up -d
"
echo "✅ [PROD-DB] Provisionamento Finalizado!"
