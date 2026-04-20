#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script de validação de documentação Solarway
.DESCRIPTION
    Verifica se caminhos mencionados em READMEs existem fisicamente
    e se comandos documentados estão atualizados.
.EXAMPLE
    .\scripts\validate-docs.ps1
#>

$ErrorActionPreference = "Stop"
$script:exitCode = 0
$script:errors = @()
$script:warnings = @()

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Solarway - Validação de Documentação" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Função para registrar erro
function Add-Error($message) {
    $script:errors += $message
    $script:exitCode = 1
    Write-Host "  [ERRO] $message" -ForegroundColor Red
}

# Função para registrar aviso
function Add-Warning($message) {
    $script:warnings += $message
    Write-Host "  [AVISO] $message" -ForegroundColor Yellow
}

# Função para registrar sucesso
function Add-Success($message) {
    Write-Host "  [OK] $message" -ForegroundColor Green
}

# ============================================
# 1. Verificar caminhos em README.md raiz
# ============================================
Write-Host "[1/5] Verificando caminhos no README.md raiz..." -ForegroundColor White

$readmeContent = Get-Content README.md -Raw

# Verificar referências a scripts/global/ (não deve existir)
if ($readmeContent -match 'scripts/global') {
    Add-Error "README.md contém referência a 'scripts/global/' (pasta não existe)"
} else {
    Add-Success "Nenhuma referência obsoleta a 'scripts/global/'"
}

# Verificar se caminhos de scripts existem
$scriptPaths = $readmeContent | Select-String -Pattern 'scripts\\([\w\-]+)\.(ps1|sh)' | ForEach-Object { $_.Matches[0].Value }
foreach ($path in $scriptPaths) {
    $fullPath = Join-Path (Get-Location) $path
    if (Test-Path $fullPath) {
        Add-Success "Script encontrado: $path"
    } else {
        Add-Error "Script não encontrado: $path"
    }
}

# ============================================
# 2. Verificar docker-compose (deprecated)
# ============================================
Write-Host ""
Write-Host "[2/5] Verificando uso de 'docker-compose' (deprecated)..." -ForegroundColor White

$readmeFiles = Get-ChildItem -Path . -Recurse -Filter "README.md"
$foundDeprecated = $false

foreach ($file in $readmeFiles) {
    $content = Get-Content $file.FullName
    $lineNumber = 1
    foreach ($line in $content) {
        # Verifica 'docker-compose' como comando (seguido de espaço ou fim de linha)
        # Não flagra 'docker-compose.yml' que é nome de arquivo válido
        if ($line -match 'docker-compose($|\s)' -and $line -notmatch '\.yml') {
            Add-Error "'$($file.FullName)' linha $lineNumber contém comando 'docker-compose' (deve ser 'docker compose')"
            $foundDeprecated = $true
        }
        $lineNumber++
    }
}

if (-not $foundDeprecated) {
    Add-Success "Nenhum uso do comando 'docker-compose' encontrado nos READMEs"
}

# ============================================
# 3. Verificar referências a null_resource
# ============================================
Write-Host ""
Write-Host "[3/5] Verificando referências a 'null_resource'..." -ForegroundColor White

$foundNullResource = $false
foreach ($file in $readmeFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match 'null_resource') {
        Add-Error "Arquivo '$($file.FullName)' contém 'null_resource' (arquitetura antiga)"
        $foundNullResource = $true
    }
}

if (-not $foundNullResource) {
    Add-Success "Nenhuma referência obsoleta a 'null_resource'"
}

# ============================================
# 4. Verificar estrutura de services/
# ============================================
Write-Host ""
Write-Host "[4/5] Verificando estrutura de services/..." -ForegroundColor White

$expectedServices = @(
    "services/backend/README.md",
    "services/bot/README.md",
    "services/db/README.md",
    "services/frontend/README.md",
    "services/proxy/README.md",
    "services/web-scrapping/README.md"
)

foreach ($service in $expectedServices) {
    if (Test-Path $service) {
        Add-Success "README encontrado: $service"
    } else {
        Add-Error "README ausente: $service"
    }
}

# ============================================
# 5. Verificar placeholders (TODO, FIXME)
# ============================================
Write-Host ""
Write-Host "[5/5] Verificando placeholders (TODO, FIXME)..." -ForegroundColor White

$foundPlaceholder = $false
foreach ($file in $readmeFiles) {
    $content = Get-Content $file.FullName
    $lineNumber = 1
    foreach ($line in $content) {
        if ($line -match 'TODO|FIXME|XXX|HACK') {
            Add-Warning "$($file.FullName):$lineNumber contém placeholder: $line"
            $foundPlaceholder = $true
        }
        $lineNumber++
    }
}

if (-not $foundPlaceholder) {
    Add-Success "Nenhum placeholder encontrado na documentação"
}

# ============================================
# Resumo
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Resumo da Validação" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($script:errors.Count -eq 0) {
    Write-Host "  Documentação validada com sucesso!" -ForegroundColor Green
    Write-Host "  Nenhum erro encontrado." -ForegroundColor Green
} else {
    Write-Host "  Erros encontrados: $($script:errors.Count)" -ForegroundColor Red
    foreach ($err in $script:errors) {
        Write-Host "    - $err" -ForegroundColor Red
    }
}

if ($script:warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "  Avisos: $($script:warnings.Count)" -ForegroundColor Yellow
    foreach ($warn in $script:warnings) {
        Write-Host "    - $warn" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

exit $script:exitCode
