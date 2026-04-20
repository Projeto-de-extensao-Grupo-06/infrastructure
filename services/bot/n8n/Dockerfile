FROM n8nio/n8n:latest

USER root

# Diretório onde ficarão os workflows e credenciais pré-carregados
RUN mkdir -p /data/workflows /data/credentials /docker-entrypoint-init.d

# Copia os workflows da raiz do contexto (services/bot/*.json)
# Se não existir nenhum JSON, o COPY falha — por isso usamos um placeholder
COPY *.json /data/workflows/

# Script que roda antes do n8n iniciar e importa os workflows via CLI
COPY n8n/init-import.sh /docker-entrypoint-init.d/init-import.sh
RUN chmod +x /docker-entrypoint-init.d/init-import.sh

USER node

# O entrypoint padrão do n8n executa os scripts de /docker-entrypoint-init.d/
# antes de iniciar o servidor. O init-import.sh carregará os workflows automaticamente.
