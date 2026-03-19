# start-local.ps1
# Script para levantar todo o ambiente localmente na ordem correta

Write-Host "Inicializando a base da infraestrutura (Redes e Bancos)..." -ForegroundColor Cyan
Set-Location services/db
docker-compose --env-file ../../.env up -d

Write-Host "Aguardando 15 segundos para inicialização inicial do Banco de Dados..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host "Inicializando o Backend (Monolito e Microserviços)..." -ForegroundColor Cyan
Set-Location ../backend/monolith
docker-compose --env-file ../../../.env up -d
Set-Location ../microservice
docker-compose --env-file ../../../.env up -d --build

Write-Host "Inicializando os Frontends..." -ForegroundColor Cyan
Set-Location ../../frontend/management-system
docker-compose --env-file ../../../.env up -d

Set-Location ../institucional-website
docker-compose --env-file ../../../.env up -d

Write-Host "Inicializando o Serviço de Bot..." -ForegroundColor Cyan
Set-Location ../../bot
docker-compose --env-file ../../.env up -d

Set-Location ../../
Write-Host "Deploy de todos os componentes locais finalizado!" -ForegroundColor Green
docker ps
