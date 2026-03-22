# setup-local.ps1
# Script para levantar todo o ambiente localmente na ordem correta

Set-Location "$PSScriptRoot\..\.."

# Load GitHub Credentials from .env
Get-Content .env | Foreach-Object {
    $name, $value = $_.split('=', 2)
    if ($name -match "GITHUB_") {
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

if ($env:GITHUB_ACCESS_TOKEN -and $env:GITHUB_USERNAME) {
    Write-Host "Realizando login no GitHub Packages..." -ForegroundColor Magenta
    echo $env:GITHUB_ACCESS_TOKEN | docker login ghcr.io -u $env:GITHUB_USERNAME --password-stdin
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

Set-Location ../../
Write-Host "Deploy de todos os componentes locais finalizado!" -ForegroundColor Green
Write-Host "  ➡️  Management:    http://localhost/ui/management" -ForegroundColor Green
Write-Host "  ➡️  Institucional: http://localhost/ui/institucional" -ForegroundColor Green
Write-Host "  ➡️  API:           http://localhost/api" -ForegroundColor Green
Write-Host "  ➡️  Healthcheck:   http://localhost/health" -ForegroundColor Green
