#!/bin/bash
# ==============================================================================
# Solarway QA Bootstrap Script (GZIP Compressed)
# ==============================================================================
set -e

# Criar estrutura de diretórios
mkdir -p /tmp/solarway/scripts/setup
mkdir -p /tmp/solarway/services/{db,bot,proxy,web-scrapping}
mkdir -p /tmp/solarway/services/backend/{monolith,microservice}
mkdir -p /tmp/solarway/services/frontend/{management-system,institucional-website}
mkdir -p /tmp/solarway/services/bot/n8n
mkdir -p /tmp/solarway/services/db/mysql-init

# 1. .env (Sensível)
cat << 'EOF' > /tmp/solarway/.env
${env_content}
EOF

# 2. Scripts de Setup
cat << 'EOF' > /tmp/solarway/scripts/setup/setup-vm.sh
${setup_vm_content}
EOF

cat << 'EOF' > /tmp/solarway/scripts/setup/setup-qa.sh
${setup_qa_content}
EOF

# 3. Docker Compose Files
cat << 'EOF' > /tmp/solarway/services/db/docker-compose.yml
${compose_db}
EOF

cat << 'EOF' > /tmp/solarway/services/backend/monolith/docker-compose.yml
${compose_monolith}
EOF

cat << 'EOF' > /tmp/solarway/services/backend/microservice/docker-compose.yml
${compose_micro}
EOF

cat << 'EOF' > /tmp/solarway/services/bot/docker-compose.yml
${compose_bot}
EOF

cat << 'EOF' > /tmp/solarway/services/frontend/management-system/docker-compose.yml
${compose_mgmt}
EOF

cat << 'EOF' > /tmp/solarway/services/frontend/institucional-website/docker-compose.yml
${compose_inst}
EOF

cat << 'EOF' > /tmp/solarway/services/proxy/docker-compose.yml
${compose_proxy}
EOF

cat << 'EOF' > /tmp/solarway/services/web-scrapping/docker-compose.yml
${compose_webscrapping}
EOF

cat << 'EOF' > /tmp/solarway/services/proxy/nginx.conf.template
${proxy_tpl}
EOF

cat << 'EOF' > /tmp/solarway/services/proxy/nginx.conf
${nginx_conf}
EOF

# 4. Arquivos Adicionais (Bot, DB, Nginx)
cat << 'EOF' > /tmp/solarway/services/bot/n8n/Dockerfile
${bot_n8n_dockerfile}
EOF

cat << 'EOF' > /tmp/solarway/services/bot/n8n/init-import.sh
${bot_n8n_init}
EOF

cat << 'EOF' > /tmp/solarway/services/bot/whatsapp-bot-ai.json
${bot_config_ai}
EOF

cat << 'EOF' > /tmp/solarway/services/bot/whatsapp-bot.json
${bot_config}
EOF

cat << 'EOF' > /tmp/solarway/services/db/mysql-init/init.sql
${db_init_sql}
EOF

# Permissões Docker (para o usuário ubuntu não precisar de sudo)
if [ -f /usr/bin/docker ]; then
    usermod -aG docker ubuntu || true
fi

# 5. Ajustes Dinâmicos e Inicialização
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
PRIVATE_IP=$(hostname -I | awk '{print $1}')

# Configurar variáveis de rede para o Nginx (Padrão de Prod)
export BACKEND_PRIVATE_IP=$PRIVATE_IP
export MANAGEMENT_PRIVATE_IP=$PRIVATE_IP
export INSTITUCIONAL_PRIVATE_IP=$PRIVATE_IP
export N8N_PRIVATE_IP=$PRIVATE_IP
export WAHA_PRIVATE_IP=$PRIVATE_IP
export DOMAIN=$PUBLIC_IP

# Gerar nginx.conf final a partir do template
envsubst '$${BACKEND_PRIVATE_IP} $${MANAGEMENT_PRIVATE_IP} $${INSTITUCIONAL_PRIVATE_IP} $${N8N_PRIVATE_IP} $${WAHA_PRIVATE_IP} $${DOMAIN}' \
    < /tmp/solarway/services/proxy/nginx.conf.template \
    > /tmp/solarway/services/proxy/nginx.conf

sed -i "s|BACKEND_BASE_URL=.*|BACKEND_BASE_URL=http://$PUBLIC_IP/api|" /tmp/solarway/.env
sed -i "s|VITE_BACKEND_BASE_URL=.*|VITE_BACKEND_BASE_URL=http://$PUBLIC_IP/api|" /tmp/solarway/.env

# Configurar n8n (Acesso Direto via Porta 5678)
cat << EOF >> /tmp/solarway/.env
N8N_PATH=/
N8N_PROTOCOL=http
N8N_HOST=$PUBLIC_IP
N8N_PORT=5678
N8N_BASE_URL=http://$PUBLIC_IP:5678/
N8N_EDITOR_BASE_URL=http://$PUBLIC_IP:5678/
N8N_WEBHOOK_URL=http://$PUBLIC_IP:5678/
EOF

# Normalizar CRLF e executar
find /tmp/solarway -type f -name "*.sh" -exec sed -i 's/\r$//' {} +
chmod +x /tmp/solarway/scripts/setup/*.sh
chmod +x /tmp/solarway/services/bot/n8n/*.sh

# Garantir que o docker está instalado antes de rodar o setup-qa
sudo bash /tmp/solarway/scripts/setup/setup-qa.sh

# 6. Automação da Conta n8n (Owner Setup)
echo "⌛ Aguardando n8n iniciar para setup do Owner..."
for i in {1..30}; do
    if curl -s http://localhost:5678/healthz > /dev/null; then
        echo "✅ n8n está pronto! Criando conta para bryangomesrocha@gmail.com..."
        curl -s -X POST http://localhost:5678/rest/owner/setup \
          -H "Content-Type: application/json" \
          -d "{
            \"email\": \"bryangomesrocha@gmail.com\",
            \"password\": \"06241234\",
            \"firstName\": \"Bryan\",
            \"lastName\": \"Rocha\"
          }" && echo "🚀 Conta n8n configurada com sucesso!" || echo "⚠️ Owner já configurado ou erro no setup."
        break
    fi
    sleep 10
done
