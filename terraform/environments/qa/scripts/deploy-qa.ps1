# deploy-qa.ps1
# Script para deploy automatizado no ambiente de QA do SolarWay
# Uso: .\scripts\deploy\deploy-qa.ps1
#
# Todas as credenciais são lidas do .env local.
# NÃO é necessário passar -var na linha de comando.

$ErrorActionPreference = "Stop"

$OriginalPath = Get-Location
$DotEnvPath = Join-Path $PSScriptRoot "../../../../.env"

# ── Carregar todas as variáveis do .env ──────────────────────────────────────
if (-not (Test-Path $DotEnvPath)) {
    throw "Arquivo .env não encontrado em: $DotEnvPath"
}

$envVars = @{}
Get-Content $DotEnvPath | ForEach-Object {
    if ($_ -match "^([^#\s][^=]*)=(.*)$") {
        $envVars[$matches[1].Trim()] = $matches[2].Trim() -replace '^["'']|["'']$', ''
    }
}

# ── Terraform Apply em QA ────────────────────────────────────────────────────
# Credenciais não são passadas como -var: estão embutidas no user_data via
# base64encode(file(".env")) dentro do main.tf do QA.
Write-Host "[DEPLOY - QA] Inicializando Terraform..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "..")

terraform init -reconfigure
terraform apply -auto-approve

if ($LASTEXITCODE -ne 0) {
    Set-Location $OriginalPath
    throw "Erro ao executar terraform apply. Verifique os logs acima."
}

# ── Output final ─────────────────────────────────────────────────────────────
$QA_IP  = terraform output -raw public_ip 2>$null
$SSM_CMD = terraform output -raw ssm_connect 2>$null
Set-Location $OriginalPath

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  [QA] Deploy finalizado!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  URL:            http://$QA_IP" -ForegroundColor White
Write-Host "  Acesso SSM:     $SSM_CMD" -ForegroundColor White
Write-Host "  Healthcheck:    http://$QA_IP/health" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Green
