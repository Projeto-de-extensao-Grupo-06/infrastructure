#!/bin/bash
# TODO - Testar budega de script
# ==============================================================================
# Ambiente: PRODUÇÃO
# Camada: Nginx Proxy EC2 (Pública - Substituto do NAT Gateway)
# Objetivo: Configurar e iniciar o Nginx como reverse proxy central.
# Dependências: setup-vm.sh deve ter sido executado antes.
# ==============================================================================
set -e

if [ "$EUID" -eq 0 ]; then
    exec > >(tee -a /var/log/solarway-setup-proxy.log|logger -t solarway-proxy -s 2>/dev/console) 2>&1
    export DEBIAN_FRONTEND=noninteractive
fi

BASE_DIR="/tmp/solarway"
PROXY_DIR="$BASE_DIR/services/proxy"

echo "➡️ [PROD-PROXY] Iniciando configuração do Nginx Reverse Proxy..."

# ── Ler IPs privados da VPC do .env ──────────────────────────────────────────
if [ -f "$BASE_DIR/.env" ]; then
    export BACKEND_PRIVATE_IP=$(grep BACKEND_PRIVATE_IP "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    export MANAGEMENT_PRIVATE_IP=$(grep MANAGEMENT_PRIVATE_IP "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    export INSTITUCIONAL_PRIVATE_IP=$(grep INSTITUCIONAL_PRIVATE_IP "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
else
    echo "❌ [PROD-PROXY] .env não encontrado em $BASE_DIR. Abortando."
    exit 1
fi

echo "➡️ [PROD-PROXY] IPs configurados:"
echo "      Backend:         ${BACKEND_PRIVATE_IP}:8000"
echo "      Management:      ${MANAGEMENT_PRIVATE_IP}:8080"
echo "      Institucional:   ${INSTITUCIONAL_PRIVATE_IP}:8081"

echo "➡️ [PROD-PROXY] Processando nginx.conf.template com envsubst..."
cd "$PROXY_DIR"
envsubst '${BACKEND_PRIVATE_IP} ${MANAGEMENT_PRIVATE_IP} ${INSTITUCIONAL_PRIVATE_IP}' \
    < nginx.conf.template > nginx.conf

echo "✅ [PROD-PROXY] nginx.conf gerado:"
cat nginx.conf

echo "⏳ [PROD-PROXY] Aguardando Docker daemon..."
while ! sudo docker info >/dev/null 2>&1; do sleep 2; done

if grep -q "GITHUB_ACCESS_TOKEN" "$BASE_DIR/.env" 2>/dev/null; then
    GITHUB_USERNAME=$(grep GITHUB_USERNAME "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    GITHUB_ACCESS_TOKEN=$(grep GITHUB_ACCESS_TOKEN "$BASE_DIR/.env" | cut -d'=' -f2 | tr -d '\r')
    echo "$GITHUB_ACCESS_TOKEN" | sudo docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin || true
fi

# ── Subir o container do proxy ────────────────────────────────────────────────
echo "🐳 [PROD-PROXY] Iniciando container nginx-proxy..."
sudo docker compose --env-file "$BASE_DIR/.env" up -d

echo "✅ [PROD-PROXY] Nginx Proxy em operação!"
echo "   Healthcheck: curl http://localhost/health"
