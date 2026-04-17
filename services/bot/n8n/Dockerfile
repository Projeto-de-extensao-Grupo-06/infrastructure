FROM n8nio/n8n:latest

USER root
RUN mkdir -p /docker-entrypoint-init.d

# Copying all potential workflows (.json) from context root into data folder
# Using wildcard cautiously if no JSON exists, it won't fail if we enforce it or we copy explicitly.
COPY *.json /data/workflows/

COPY n8n/init-import.sh /docker-entrypoint-init.d/
RUN chmod +x /docker-entrypoint-init.d/init-import.sh

USER node
