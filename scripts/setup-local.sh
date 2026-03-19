#!/bin/bash
# setup-local.sh
# TODO - Testar budega de script
# Script para levantar todo o ambiente localmente na ordem correta

cd "$(dirname "$0")/.."

echo -e "\e[36mInicializando a base da infraestrutura (Redes e Bancos)...\e[0m"
cd services/db
docker compose --env-file ../../.env up -d

echo -e "\e[33mAguardando 30 segundos para inicialização inicial do Banco de Dados...\e[0m"
sleep 30

echo -e "\e[36mInicializando o Backend (Monolito e Microserviços)...\e[0m"
cd ../backend/monolith
docker compose --env-file ../../../.env up -d
cd ../microservice
docker compose --env-file ../../../.env up -d --build

echo -e "\e[36mInicializando os Frontends...\e[0m"
cd ../../frontend/management-system
docker compose --env-file ../../../.env up -d

cd ../institucional-website
docker compose --env-file ../../../.env up -d

echo -e "\e[36mInicializando o Serviço de Bot...\e[0m"
cd ../../bot
docker compose --env-file ../../.env up -d

cd ../../
echo -e "\e[32mDeploy de todos os componentes locais finalizado!\e[0m"
docker ps
