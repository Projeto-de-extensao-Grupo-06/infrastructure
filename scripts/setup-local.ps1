# setup-local.ps1
# Script para levantar todo o ambiente localmente na ordem correta

Set-Location "$PSScriptRoot\.."

# Load GitHub Credentials from .env
Get-Content .env | Foreach-Object {
    $name, $value = $_.split('=', 2)
    if ($name -match "GITHUB_") {
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

if ($env:GITHUB_ACCESS_TOKEN -and $env:GITHUB_USERNAME) {
    Write-Host "Realizando login no GitHub Packages..." -ForegroundColor Magenta
    Write-Output $env:GITHUB_ACCESS_TOKEN | docker login ghcr.io -u $env:GITHUB_USERNAME --password-stdin
}

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

Write-Host "Inicializando o Nginx Proxy (entry point local)..." -ForegroundColor Cyan
Set-Location ../proxy
docker-compose --env-file ../../.env up -d

Write-Host "Inicializando o Web Scrapping (execução a cada 24h)..." -ForegroundColor Cyan
Set-Location ../web-scrapping
docker-compose --env-file ../../.env up -d

Set-Location ../../
Write-Host ""
Write-Host "======================================================" -ForegroundColor DarkCyan
Write-Host "  Deploy local finalizado!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Interfaces de Usuário:"  -ForegroundColor White
Write-Host "  ➡️  Management System:   http://localhost/" -ForegroundColor Green
Write-Host "  ➡️  Site Institucional:  http://localhost/institucional" -ForegroundColor Green
Write-Host ""
Write-Host "  APIs e Serviços:"  -ForegroundColor White
Write-Host "  ➡️  API Backend (REST):  http://localhost/api" -ForegroundColor Cyan
Write-Host "  ➡️  Schedule Service:    http://localhost/schedule" -ForegroundColor Cyan
Write-Host "  ➡️  Healthcheck Proxy:   http://localhost/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Bot WhatsApp:"  -ForegroundColor White
Write-Host "  ➡️  n8n (fluxos):        http://localhost/n8n" -ForegroundColor Yellow
Write-Host "  ➡️  WAHA (dashboard):    http://localhost/waha/dashboard" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Banco de Dados (acesso externo):"  -ForegroundColor White
Write-Host "  ➡️  MySQL:               localhost:3307" -ForegroundColor DarkGray
Write-Host "======================================================" -ForegroundColor DarkCyan
Write-Host ""
