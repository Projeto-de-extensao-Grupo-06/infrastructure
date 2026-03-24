# deploy-qa.ps1
# Script para deploy automatizado no ambiente de QA do SolarWay
# Uso: .\scripts\deploy\deploy-qa.ps1

$ErrorActionPreference = "Stop"

# 1. Chamar o Terraform para infra + deploy embutido
Write-Host "[DEPLOY - AWS] Iniciando Terraform Apply em QA (Infra + Deploy)..." -ForegroundColor Cyan
$OriginalPath = Get-Location
Set-Location terraform/environments/qa

# Inicializa se necessário e aplica mudanças
terraform init -reconfigure
terraform apply -auto-approve

if ($LASTEXITCODE -ne 0) {
    Set-Location $OriginalPath
    throw "Erro ao executar terraform apply. Verifique os logs acima."
}

# 2. Obter IP final para feedback
$QA_IP = terraform output -raw public_ip
Set-Location $OriginalPath

Write-Host "[DEPLOY - AWS] ✅ Processo finalizado com sucesso em http://$QA_IP" -ForegroundColor Green
