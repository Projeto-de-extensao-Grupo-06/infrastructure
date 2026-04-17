#!/bin/bash
# TODO - Testar budega de script
# ==============================================================================
# Ambiente: PRODUÇÃO
# Camada: Bot EC2 (WhatsApp Waha & n8n / Webscraping)
# Objetivo: Bootstrap nativo focado nas engine de bots escaláveis da AWS
# ==============================================================================
set -e
if [ "$EUID" -eq 0 ]; then
    exec > >(tee /var/log/user-data-prod-bot.log|logger -t user-data -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

echo "➡️ [PROD-BOT] Configurando Código..."
sudo su - "$TARGET_USER" -c "
  BASE_DIR="/tmp/solarway"
  cd "$BASE_DIR"
  echo 'Aguardando Docker daemon...'
  while ! docker info >/dev/null 2>&1; do sleep 2; done

  # Diferenciação de apps baseada em variável de ambiente (BOT_TYPE)
  if [[ "$BOT_TYPE" == "chatbot" || -z "$BOT_TYPE" ]]; then
    echo "➡️ [PROD-BOT] Iniciando Chatbot Stack (n8n, WAHA, Redis)..."
    cd services/bot
    docker compose pull
    docker compose --env-file ../../.env up -d
    cd ../..
  fi

  if [[ "$BOT_TYPE" == "webscraping" ]]; then
    echo "➡️ [PROD-BOT] Camada de Webscraping detectada. (Aguardando configuração de serviço em services/webscraping)"
    # cd services/webscraping && docker compose up -d
  fi
"
echo "✅ [PROD-BOT] Provisionamento Finalizado!"
