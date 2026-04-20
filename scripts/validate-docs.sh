#!/bin/bash
# =============================================================================
# Solarway - Validação de Documentação (Bash/Linux)
# Verifica se caminhos mencionados em READMEs existem fisicamente
# =============================================================================

set -e

EXIT_CODE=0
ERRORS=()
WARNINGS=()

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
CYAN='\033[0;36m'

# Função para registrar erro
add_error() {
    ERRORS+=("$1")
    EXIT_CODE=1
    echo -e "  ${RED}[ERRO]${NC} $1"
}

# Função para registrar aviso
add_warning() {
    WARNINGS+=("$1")
    echo -e "  ${YELLOW}[AVISO]${NC} $1"
}

# Função para registrar sucesso
add_success() {
    echo -e "  ${GREEN}[OK]${NC} $1"
}

echo -e "${CYAN}========================================"
echo "  Solarway - Validação de Documentação"
echo -e "========================================${NC}"
echo ""

# ============================================
# 1. Verificar caminhos em README.md raiz
# ============================================
echo -e "${CYAN}[1/5] Verificando caminhos no README.md raiz...${NC}"

if grep -q "scripts/global" README.md; then
    add_error "README.md contém referência a 'scripts/global/' (pasta não existe)"
else
    add_success "Nenhuma referência obsoleta a 'scripts/global/'"
fi

# Verificar se caminhos de scripts existem
while IFS= read -r line; do
    if [[ $line =~ scripts/([a-zA-Z0-9_-]+)\.(ps1|sh) ]]; then
        script_path="${BASH_REMATCH[0]}"
        if [ -f "$script_path" ]; then
            add_success "Script encontrado: $script_path"
        else
            add_error "Script não encontrado: $script_path"
        fi
    fi
done < <(grep -oE 'scripts/[a-zA-Z0-9_-]+\.(ps1|sh)' README.md || true)

# ============================================
# 2. Verificar docker-compose (deprecated)
# ============================================
echo ""
echo -e "${CYAN}[2/5] Verificando uso de 'docker-compose' (deprecated)...${NC}"

FOUND_DEPRECATED=false
while IFS= read -r file; do
    if grep -q "docker-compose" "$file"; then
        add_error "Arquivo '$file' contém 'docker-compose' (deve ser 'docker compose')"
        FOUND_DEPRECATED=true
    fi
done < <(find . -name "README.md" -type f)

if [ "$FOUND_DEPRECATED" = false ]; then
    add_success "Nenhum uso de 'docker-compose' encontrado nos READMEs"
fi

# ============================================
# 3. Verificar referências a null_resource
# ============================================
echo ""
echo -e "${CYAN}[3/5] Verificando referências a 'null_resource'...${NC}"

FOUND_NULL=false
while IFS= read -r file; do
    if grep -q "null_resource" "$file"; then
        add_error "Arquivo '$file' contém 'null_resource' (arquitetura antiga)"
        FOUND_NULL=true
    fi
done < <(find . -name "README.md" -type f)

if [ "$FOUND_NULL" = false ]; then
    add_success "Nenhuma referência obsoleta a 'null_resource'"
fi

# ============================================
# 4. Verificar estrutura de services/
# ============================================
echo ""
echo -e "${CYAN}[4/5] Verificando estrutura de services/...${NC}"

EXPECTED_SERVICES=(
    "services/backend/README.md"
    "services/bot/README.md"
    "services/db/README.md"
    "services/frontend/README.md"
    "services/proxy/README.md"
    "services/web-scrapping/README.md"
)

for service in "${EXPECTED_SERVICES[@]}"; do
    if [ -f "$service" ]; then
        add_success "README encontrado: $service"
    else
        add_error "README ausente: $service"
    fi
done

# ============================================
# 5. Verificar placeholders (TODO, FIXME)
# ============================================
echo ""
echo -e "${CYAN}[5/5] Verificando placeholders (TODO, FIXME)...${NC}"

FOUND_PLACEHOLDER=false
while IFS= read -r file; do
    while IFS= read -r line; do
        if echo "$line" | grep -qE 'TODO|FIXME|XXX|HACK'; then
            add_warning "$file contém placeholder: $(echo "$line" | grep -oE 'TODO|FIXME|XXX|HACK')"
            FOUND_PLACEHOLDER=true
        fi
    done < "$file"
done < <(find . -name "README.md" -type f)

if [ "$FOUND_PLACEHOLDER" = false ]; then
    add_success "Nenhum placeholder encontrado na documentação"
fi

# ============================================
# Resumo
# ============================================
echo ""
echo -e "${CYAN}========================================"
echo "  Resumo da Validação"
echo -e "========================================${NC}"
echo ""

if [ ${#ERRORS[@]} -eq 0 ]; then
    echo -e "  ${GREEN}Documentação validada com sucesso!${NC}"
    echo -e "  ${GREEN}Nenhum erro encontrado.${NC}"
else
    echo -e "  ${RED}Erros encontrados: ${#ERRORS[@]}${NC}"
    for err in "${ERRORS[@]}"; do
        echo -e "    ${RED}- $err${NC}"
    done
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}Avisos: ${#WARNINGS[@]}${NC}"
    for warn in "${WARNINGS[@]}"; do
        echo -e "    ${YELLOW}- $warn${NC}"
    done
fi

echo ""
echo -e "${CYAN}========================================${NC}"

exit $EXIT_CODE
