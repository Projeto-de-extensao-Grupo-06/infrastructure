# deploy-qa.ps1
# Script para deploy automatizado no ambiente de QA do SolarWay
# Uso: .\scripts\deploy\deploy-qa.ps1

$ErrorActionPreference = "Stop"

# 1. Chamar o Terraform para infra + deploy embutido
Write-Host "[DEPLOY - AWS] Iniciando Terraform Apply em QA (Infra + Deploy)..." -ForegroundColor Cyan
$OriginalPath = Get-Location
Set-Location terraform/environments/qa

# Carregar variáveis do .env
$DotEnvPath = "../../../.env"
if (Test-Path $DotEnvPath) {
    Get-Content $DotEnvPath | Foreach-Object {
        if ($_ -match "^([^#\s][^=]*)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim() -replace '^["'']|["'']$', ''
            Set-Variable -Name "DOTENV_$name" -Value $value -ErrorAction SilentlyContinue
        }
    }
}

$KEY_NAME = if ($DOTENV_AWS_KEY_NAME) { $DOTENV_AWS_KEY_NAME } else { "solarway" }
$G_USER   = if ($DOTENV_GITHUB_USERNAME) { $DOTENV_GITHUB_USERNAME } else { "" }
$G_TOKEN  = if ($DOTENV_GITHUB_ACCESS_TOKEN) { $DOTENV_GITHUB_ACCESS_TOKEN } else { "" }

Write-Host "➡️ Usando chave: $KEY_NAME" -ForegroundColor Gray

# Inicializa se necessário e aplica mudanças
terraform init -reconfigure
terraform apply -auto-approve `
    -var="key_name=$KEY_NAME" `
    -var="github_username=$G_USER" `
    -var="github_token=$G_TOKEN"

if ($LASTEXITCODE -ne 0) {
    Set-Location $OriginalPath
    throw "Erro ao executar terraform apply. Verifique os logs acima."
}

# 2. Obter IP final para feedback
$QA_IP = terraform output -raw public_ip
Set-Location $OriginalPath

Write-Host "[DEPLOY - AWS] ✅ Processo finalizado com sucesso em http://$QA_IP" -ForegroundColor Green
