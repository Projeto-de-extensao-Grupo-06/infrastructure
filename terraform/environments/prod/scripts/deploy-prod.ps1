# deploy-prod.ps1
# Script para deploy automatizado no ambiente de PRODUÇÃO do SolarWay
# Uso: .\scripts\deploy\deploy-prod.ps1
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

# ── Mapear variáveis necessárias para os módulos Terraform (deploy.tf) ───────
$TF_VARS = @{
    "db_password"    = $envVars["DB_PASSWORD"]
    "redis_password" = "default"
    "bot_secret"     = $envVars["BOT_SECRET"]
    "email"          = $envVars["EMAIL"]
    "email_password" = $envVars["PASSWORD_EMAIL"]
    "bucket_name"    = $envVars["BUCKET_NAME"]
    "github_username"= $envVars["GITHUB_USERNAME"]
    "github_token"   = $envVars["GITHUB_ACCESS_TOKEN"]
}

$varArgs = $TF_VARS.GetEnumerator() | ForEach-Object { "-var=`"$($_.Key)=$($_.Value)`"" }

# ── Terraform Apply em PROD ──────────────────────────────────────────────────
Write-Host "[DEPLOY - PROD] Inicializando Terraform..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "..")

terraform init -reconfigure
terraform apply -auto-approve @varArgs

if ($LASTEXITCODE -ne 0) {
    Set-Location $OriginalPath
    throw "Erro ao executar terraform apply. Verifique os logs acima."
}

# ── Output final ─────────────────────────────────────────────────────────────
$NGINX_IP = terraform output -raw nginx_public_ip 2>$null
$SSM_CMD  = terraform output -raw nginx_ssm_connect 2>$null
Set-Location $OriginalPath

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  [PROD] Deploy finalizado!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Nginx IP:       $NGINX_IP" -ForegroundColor White
Write-Host "  Acesso SSM:     $SSM_CMD" -ForegroundColor White
Write-Host "  Healthcheck:    http://$NGINX_IP/health" -ForegroundColor White
Write-Host "  HTTPS (futuro): https://<seu-domínio>/health" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Green
