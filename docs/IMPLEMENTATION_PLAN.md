# Plano de Implementação Solarway - Relatório de Análise e Integração

**Data:** 2026-04-17  
**Versão:** 1.1  
**Escopo:** Análise de Documentação como Artefato de Controle, SSM, Variáveis de Ambiente, Integração PROD e Open Questions

---

## Sumário Executivo

Este relatório consolida a análise técnica de cinco áreas críticas da infraestrutura Solarway:
1. **Documentação como Artefato de Controle de Execução** (⚠️ Crítico)
2. Estratégia de SSM (Systems Manager)
3. Utilização de Variáveis de Ambiente
4. Plano de Integração do Ambiente PROD
5. Open Questions e Dependências Externas

Cada seção contém diagnóstico atual, gaps identificados e plano de ação faseado com checkpoints de verificação.

---

## Parte 0: Documentação como Artefato de Controle de Execução

### 0.1 Conceito e Importância Crítica

Neste projeto, a **documentação (READMEs, INFRA_PLAN.md, README.md) funciona como artefato de controle de execução** — não apenas como referência informativa, mas como especificação normativa que determina:

1. **Sequência de execução** (ordem de deploy dos serviços)
2. **Parâmetros de entrada** (variáveis obrigatórias)
3. **Critérios de sucesso** (healthchecks e validações)
4. **Decisões arquiteturais** (padrões que devem ser seguidos)

> ⚠️ **Quando a documentação diverge da implementação real, ela se torna um risco operacional:** desenvolvedores executam comandos baseados em instruções desatualizadas, causando falhas em produção.

### 0.2 Diagnóstico de Divergências Críticas

#### 🔴 Divergência 1: INFRA_PLAN.md vs Implementação Real

**Arquivo:** `docs/INFRA_PLAN.md`

| Seção no Documento | Realidade do Código | Impacto |
|-------------------|---------------------|---------|
| "Vamos tolerar temporariamente o uso de SSH Bastion com chave `.pem` exclusivamente na pipeline do Null_Resource" | Código NÃO usa null_resource nem SSH Bastion; usa SSM Associations | **Alto** - Documentação desatualizada causa confusão sobre arquitetura atual |
| Menciona NAT Gateway managed | Implementação usa NAT IaaS (IPTables na EC2 Nginx) | **Médio** - Risco de custos inesperados se alguém seguir a doc |
| Fase 4: "SSM / IAM" como futura | Já implementado em PROD via `aws_ssm_association` | **Médio** - Prioridade incorreta |

#### 🔴 Divergência 2: READMEs de Serviços vs Docker Compose

**Exemplo concreto em `services/backend/README.md`:**
```markdown
# Como Fazer Build / Atualizar Imagens
...
docker build -t ghcr.io/.../springboot-web-backend:latest .
```

**Realidade:** O `docker-compose.yml` do backend monolith usa:
```yaml
services:
  backend-service:
    image: ghcr.io/projeto-de-extensao-grupo-06/springboot-web-backend:latest
    # NÃO há build: . no compose
```

**Impacto:** Desenvolvedor segue README tentando fazer build local, mas o compose espera pull de imagem pronta.

#### 🔴 Divergência 3: Instruções de Portas vs .env.example

**READMEs** listam portas específicas (ex: "Porta 8000 para backend"), mas:
- `.env.example` define `PORT_BACKEND_MONOLITH=8000`
- Scripts de deploy podem sobrescrever dinamicamente
- QA usa mapeamento diferente via Terraform

**Impacto:** Falha de comunicação entre equipes sobre qual porta é a "verdade".

#### 🔴 Divergência 4: Setup Scripts Documentados vs Existentes

**Documentação menciona:**
```powershell
# Windows (PowerShell):
.\scripts\global\setup-local.ps1
```

**Realidade:** Scripts foram movidos para `scripts/setup-local.ps1` (sem pasta `global/`).

**Impacto:** Comando falha imediatamente para novos desenvolvedores.

### 0.3 Checklist de Sincronização Código ↔ Documentação

Para cada alteração no código, a seguinte matriz de documentação deve ser atualizada:

| Alteração em Código | README Afetado | INFRA_PLAN.md | .env.example | CHANGELOG |
|--------------------|----------------|---------------|--------------|-----------|
| Nova variável de ambiente | ✅ README do serviço | ⚠️ Se afeta arquitetura | ✅ Sempre | ✅ Sim |
| Mudança de porta | ✅ README raiz + serviço | ⚠️ Se afeta rede | ✅ Sempre | ✅ Sim |
| Novo serviço | ✅ README novo + raiz | ✅ Sempre | ✅ Sempre | ✅ Sim |
| Alteração em script de deploy | ✅ README infra | ✅ Sempre | N/A | ✅ Sim |
| Mudança de IAM/SSM | N/A | ✅ Sempre | N/A | ✅ Sim |
| Alteração de ordem de inicialização | ✅ README raiz | ✅ Se afeta fases | N/A | ✅ Sim |

### 0.4 Plano de Correção de Documentação (Gating para PROD)

Antes de declarar PROD "pronto para produção", os seguintes artefatos de documentação devem ser auditados:

#### Fase DOC-1: Validação de Caminhos (1 dia) ✅ COMPLETADA
- [x] Verificar se todos os caminhos de scripts nos READMEs existem fisicamente
- [x] Validar que comandos copiáveis funcionam em ambiente limpo
- [x] Corrigir referências a `scripts/global/` → `scripts/`

**Resultado:** 7 correções aplicadas em 6 arquivos. Relatório completo em `docs/DOC-1_REPORT.md`.

#### Fase DOC-2: Sincronização de Variáveis (2 dias)
- [ ] Auditar `services/*/README.md` para variáveis mencionadas vs `.env.example`
- [ ] Criar `VARIABLES_REFERENCE.md` central com todas as vars e seus usos
- [ ] Garantir que cada serviço documenta suas dependências de env

#### Fase DOC-3: Atualização de Arquitetura (2 dias)
- [ ] Reescrever seções do INFRA_PLAN.md que mencionam SSH/null_resource
- [ ] Documentar arquitetura SSM atual (Associations, Session Manager)
- [ ] Atualizar diagramas (se houver) para refletir NAT IaaS

#### Fase DOC-4: Criação de Runbooks (3 dias)
- [ ] Criar `RUNBOOK_DEPLOY_QA.md` - Passo a passo de deploy QA com troubleshooting
- [ ] Criar `RUNBOOK_DEPLOY_PROD.md` - Passo a passo de deploy PROD com rollback
- [ ] Criar `RUNBOOK_TROUBLESHOOTING.md` - Erros comuns e soluções

#### Fase DOC-5: Verificação Automatizada (Ongoing)
- [ ] Criar script `scripts/validate-docs.ps1/sh` que:
  - Verifica se paths mencionados em READMEs existem
  - Valida que variáveis no .env.example são usadas em ao menos um compose
  - Alerta sobre placeholders (TODO, FIXME) em documentação

### 0.5 Template de README para Serviços

Padronização para novos serviços (a ser aplicado em documentação existente):

```markdown
# Nome do Serviço

## Propósito
[Uma frase sobre o que este serviço faz]

## Dependências
- [ ] Serviço X (porta Y)
- [ ] Variável de ambiente Z obrigatória

## Variáveis de Ambiente Obrigatórias
| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| VAR_NAME | Descrição | valor |

## Como Executar Localmente
\`\`\`bash
cd services/nome-do-servico
docker-compose --env-file ../../.env up -d
\`\`\`

## Como Executar em QA/PROD
[Referência ao script de deploy]

## Healthcheck
\`\`\`bash
curl http://localhost:PORTA/health
# Resposta esperada: ...
\`\`\`

## Troubleshooting
| Erro | Causa Provável | Solução |
|------|----------------|---------|
| ... | ... | ... |
```

### 0.6 Artefatos de Controle Prioritários

A seguinte ordem de prioridade deve ser respeitada para documentação:

1. **🔴 CRÍTICO** - `README.md` (raiz) - Primeira impressão do projeto
2. **🔴 CRÍTICO** - `.env.example` - Contrato de variáveis entre infra e dev
3. **🟡 ALTA** - `services/*/README.md` - Como usar cada serviço
4. **🟡 ALTA** - `INFRA_PLAN.md` - Decisões arquiteturais e roadmap
5. **🟢 MÉDIA** - `IMPLEMENTATION_PLAN.md` - Este documento
6. **🟢 MÉDIA** - Scripts de deploy documentados inline

---

## Parte 1: Análise da Estratégia de SSM

### 1.1 Diagnóstico Atual

O projeto utiliza AWS Systems Manager (SSM) em dois níveis distintos:

#### Nível 1: Acesso às Instâncias (Session Manager)
- **QA:** Output `ssm_connect` gera comando `aws ssm start-session --target <instance-id>`
- **PROD:** Output `nginx_ssm_connect` para acesso ao Nginx Proxy
- **Módulo VPC:** Endpoints SSM (`aws_vpc_endpoint` para `ssm` e `ssmmessages`) configurados

#### Nível 2: Configuração via SSM Associations (PROD apenas)
- **PROD `deploy.tf`:** Utiliza `aws_ssm_association` com document `AWS-RunShellScript`
- **Função:** Injeção de arquivos `.env` customizados em cada EC2 privada sem SSH
- **Dependências Orquestradas:**
  ```
  env_db → env_backend_1 → env_frontend_1
         → env_backend_2 → env_frontend_2
         → env_bot
  ```

### 1.2 Avaliação de Eficácia

| Aspecto | Status | Observação |
|---------|--------|------------|
| Eliminação de SSH/.pem | ✅ Parcial | QA ainda menciona SSH em documentação antiga; PROD usa SSM completamente |
| VPC Endpoints SSM | ✅ Configurado | Presente em `modules/vpc/main.tf` |
| IAM Instance Profile | ⚠️ Hardcoded | Valor "LabInstanceProfile" fixo no código |
| Associations para Config | ✅ Bem usado | PROD usa pattern correto de injeção de .env |
| Session Manager Output | ✅ Funcional | Ambos ambientes exportam comando SSM |

### 1.3 Gaps Identificados

#### Gap 1: IAM Instance Profile Hardcoded
```hcl
# Em terraform/environments/prod/main.tf e qa/main.tf
iam_instance_profile = "LabInstanceProfile"  # Hardcoded
```
**Risco:** Dependência de recurso criado manualmente fora do Terraform.
**Mitigação:** Criar módulo IAM dedicado ou documentar dependência.

#### Gap 2: Documentação Divergente
O INFRA_PLAN.md menciona:
> "Vamos tolerar temporariamente o uso de SSH Bastion com chave `.pem` exclusivamente na pipeline do Null_Resource"

**Problema:** O código atual NÃO usa null_resource nem SSH; usa SSM Associations. Documentação desatualizada.

#### Gap 3: Falta de Verificação de SSM
Não há healthcheck automatizado para confirmar que SSM agent está respondendo nas instâncias privadas.

### 1.4 Recomendações

1. **Criar módulo IAM:** Gerenciar `aws_iam_role` + `aws_iam_instance_profile` com policy `AmazonSSMManagedInstanceCore`
2. **Atualizar documentação:** Remover referências a null_resource e SSH
3. **Adicionar healthcheck SSM:** Verificar `aws ssm describe-instance-information` no script de deploy

---

## Parte 2: Análise de Variáveis de Ambiente

### 2.1 Mapeamento de Variáveis

#### Variáveis Globais (`.env` local)

| Variável | Usada em Local | Usada em QA | Usada em PROD | Template PROD | Status |
|----------|----------------|-------------|---------------|---------------|--------|
| `DB_USERNAME` | ✅ | ✅ | ? | env.db.tmpl | ⚠️ Não verificado |
| `DB_PASSWORD` | ✅ | ✅ | ✅ | env.db.tmpl | ✅ Mapeada em deploy.tf |
| `REDIS_PASSWORD` | ✅ | ✅ | ✅ | env.db.tmpl | ✅ Mapeada em deploy.tf |
| `EMAIL` | ✅ | ✅ | ✅ | env.backend.tmpl | ✅ Mapeada |
| `PASSWORD_EMAIL` | ✅ | ✅ | ✅ | env.backend.tmpl | ✅ Mapeada como `email_password` |
| `BOT_SECRET` | ✅ | ✅ | ✅ | env.backend.tmpl, env.bot.tmpl | ✅ Mapeada |
| `GITHUB_USERNAME` | ✅ | ✅ | ✅ | Múltiplos | ✅ Mapeada |
| `GITHUB_ACCESS_TOKEN` | ✅ | ✅ | ✅ | Múltiplos | ✅ Mapeada como `github_token` |
| `BUCKET_NAME` | ✅ | ? | ✅ | env.backend.tmpl | ⚠️ Verificar se usada em QA |
| `AWS_ACCESS_KEY_ID` | ✅ | ✅ | ? | ? | ⚠️ Verificar templates PROD |
| `AWS_SECRET_ACCESS_KEY` | ✅ | ✅ | ? | ? | ⚠️ Verificar templates PROD |
| `AWS_SESSION_TOKEN` | ✅ | ✅ | ? | ? | ⚠️ Verificar templates PROD |
| `AWS_KEY_NAME` | ✅ | ✅ | ✅ | N/A (TF var) | ✅ Usada como `key_name` |

#### Variáveis de Porta

Todas as variáveis `PORT_*` são consistentemente usadas em:
- `docker-compose.yml` files (mapeamento de portas host)
- `.env.example` (documentação)
- Bootstrap scripts (impressão de URLs)

### 2.2 Inconsistências Encontradas

#### Inconsistência 1: Nomenclatura de Variáveis
```
.env:          PASSWORD_EMAIL
deploy.tf:     email_password (snake_case)
```
**Recomendação:** Padronizar para `EMAIL_PASSWORD` no .env.

#### Inconsistência 2: Variáveis AWS em PROD
As credenciais AWS (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) são:
- Definidas em `.env.example`
- Usadas em scripts locais e QA
- **NÃO VERIFICADAS** nos templates PROD

**Risco:** PROD pode não ter acesso ao S3 se não estiverem nos templates.

#### Inconsistência 3: REDIS_PASSWORD
- `.env.example` não define `REDIS_PASSWORD` explícito
- PROD usa `"default"` hardcoded no deploy-prod.ps1
- **Risco:** Segurança comprometida

### 2.3 Cobertura de Templates PROD

Templates esperados em `terraform/environments/prod/templates/`:
- `env.db.tmpl` - ⚠️ Não verificado se existe
- `env.backend.tmpl` - ⚠️ Não verificado se existe
- `env.frontend.tmpl` - ⚠️ Não verificado se existe
- `env.bot.tmpl` - ⚠️ Não verificado se existe

**Ação Requerida:** Verificar existência e conteúdo destes templates.

### 2.4 Recomendações

1. **Adicionar `REDIS_PASSWORD`** ao `.env.example` com valor seguro
2. **Auditar templates PROD** para garantir todas as variáveis necessárias estão presentes
3. **Criar validador de env:** Script que verifica se todas as variáveis do .env.example estão presentes no .env real
4. **Padronizar nomenclatura:** Migrar `PASSWORD_EMAIL` → `EMAIL_PASSWORD`

---

## Parte 3: Plano de Integração PROD

### 3.1 Arquitetura PROD Atual

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS PROD                            │
│  ┌──────────────┐                                           │
│  │   Internet   │                                           │
│  └──────┬───────┘                                           │
│         │                                                   │
│  ┌──────▼───────┐    ┌──────────┐    ┌──────────────────┐  │
│  │ ec2_nginx    │────│ Public   │    │   Subnets        │  │
│  │ (Proxy NAT)  │    │ Subnet   │    │   Privadas       │  │
│  │ Portas: 80   │    │ 10.0.0.0/28    │   (4x /28)       │  │
│  │          443 │    └──────────┘    └──────────────────┘  │
│  └──────┬───────┘                                           │
│         │ MASQUERADE (IPTables)                             │
│  ┌──────▼──────────────────────────────────────────────────┐ │
│  │                    Private Subnets                      │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │ │
│  │  │ec2_db    │ │backend_1 │ │frontend_1│ │ ec2_bot  │   │ │
│  │  │(t3.large)│ │(t3.medium│ │(t3.small)│ │(t3.small)│   │ │
│  │  │3306,6379 │ │   :8000  │ │  :8081   │ │5678,3000 │   │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐                  │ │
│  │  │backend_2 │ │frontend_2│ │webscrap  │                  │ │
│  │  │(t3.medium│ │(t3.small)│ │(t3.micro)│                  │ │
│  │  │   :8082  │ │  :8080   │ │  :5000   │                  │ │
│  │  └──────────┘ └──────────┘ └──────────┘                  │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Características PROD

| Característica | Implementação | Status |
|----------------|---------------|--------|
| Alta Disponibilidade | 7 EC2 distribuídas | ⚠️ Single AZ (1a) |
| Load Balancing | Nginx Proxy (manual) | ✅ Funcional |
| NAT | IaaS (IPTables) | ✅ Implementado |
| SSL/TLS | Let's Encrypt (staging) | ⚠️ Simulado |
| Secrets Management | SSM + templates | ✅ Bem estruturado |
| VPC Endpoints | S3 | ✅ Configurado |

### 3.3 Plano Faseado de Integração

#### FASE 1: Fundação e Validação (Semana 1-2)

**Objetivo:** Garantir que a base PROD está sólida antes de adicionar complexidade.

| Task | Descrição | Verificação |
|------|-----------|-------------|
| 1.1 | Verificar existência dos templates `.tmpl` em `prod/templates/` | `ls -la terraform/environments/prod/templates/` |
| 1.2 | Validar conteúdo de cada template contra `.env.example` | Comparar variáveis |
| 1.3 | Testar deploy em conta AWS limpa (sandbox) | `terraform plan` sem erros |
| 1.4 | Documentar valores mínimos de `.env` necessários | Criar `.env.prod.example` |
| 1.5 | Criar script de validação de pré-requisitos | `./scripts/validate-prod-prereqs.ps1` |

**Checkpoint de Fase 1:**
```bash
# Comando de validação
terraform plan -var-file="prod.tfvars" 2>&1 | grep -E "(Error|Warning|No changes)"
# Esperado: "No changes" ou lista planejada sem erros
```

#### FASE 2: Segurança e Acesso (Semana 3)

**Objetivo:** Eliminar dependências manuais e hardcoded.

| Task | Descrição | Verificação |
|------|-----------|-------------|
| 2.1 | Criar módulo IAM para Instance Profile | `terraform plan` mostra criação de role |
| 2.2 | Substituir "LabInstanceProfile" hardcoded | Buscar/replace em main.tf |
| 2.3 | Adicionar validação SSM healthcheck | `aws ssm describe-instance-information` |
| 2.4 | Configurar REDIS_PASSWORD seguro | Atualizar .env e deploy.tf |
| 2.5 | Auditoria de Security Groups | Verificar se portas estão mínimas |

**Checkpoint de Fase 2:**
```bash
# Verificar SSM connectivity
aws ssm describe-instance-information --filters Key=InstanceIds,Values=<instance-id>
# Esperado: Status "Active", PingStatus "Online"
```

#### FASE 3: Backend Remoto Terraform (Semana 4)

**Objetivo:** Implementar backend S3 + DynamoDB para state compartilhado.

| Task | Descrição | Verificação |
|------|-----------|-------------|
  | 3.1 | Criar bucket S3 para tfstate | `aws s3 ls` mostra bucket |
| 3.2 | Criar tabela DynamoDB para lock | `aws dynamodb describe-table` |
| 3.3 | Atualizar `terraform` bloco em `main.tf` | Verificar backend "s3" configurado |
| 3.4 | Migrar state local para remoto | `terraform init -migrate-state` |
| 3.5 | Testar lock de state | Tentar 2 applies simultâneos |

**Checkpoint de Fase 3:**
```bash
# Verificar backend
terraform state list
# Deve funcionar em máquina diferente com mesmo backend
```

#### FASE 4: Integração QA → PROD (Semana 5-6)

**Objetivo:** Criar pipeline de promoção de código e configurações.

| Task | Descrição | Verificação |
|------|-----------|-------------|
| 4.1 | Criar script `promote-qa-to-prod.ps1` | Copiar configs QA → PROD |
| 4.2 | Implementar validação de compose files | `docker-compose config` nos scripts |
| 4.3 | Criar documentação de rollback | `ROLLBACK.md` com procedimentos |
| 4.4 | Testar ciclo completo: Local → QA → PROD | Deploy end-to-end |
| 4.5 | Documentar diferenças de arquitetura | `PROD_VS_QA.md` |

**Checkpoint de Fase 4:**
```powershell
# Teste de promoção
.\scripts\promote-qa-to-prod.ps1 -ValidateOnly
# Esperado: Validações passam sem erro
```

#### FASE 5: Automação e CI/CD (Semana 7-8)

**Objetivo:** Preparar para GitHub Actions (documentado no INFRA_PLAN.md).

| Task | Descrição | Verificação |
|------|-----------|-------------|
| 5.1 | Criar OIDC provider manualmente | Documentar ARN |
| 5.2 | Criar role IAM para GitHub Actions | Trust policy para OIDC |
| 5.3 | Documentar workflow de deploy | `.github/workflows/deploy.yml` exemplo |
| 5.4 | Testar deploy via GitHub (manual trigger) | Workflow run sucedido |

**Checkpoint de Fase 5:**
```yaml
# Workflow de teste deve passar
- name: Deploy to PROD
  run: terraform apply -auto-approve
```

### 3.4 Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Templates PROD ausentes | Alta | Alto | Fase 1 - verificação prévia |
| State lock não implementado | Média | Alto | Fase 3 - prioridade máxima |
| Dependência de LabInstanceProfile | Alta | Médio | Fase 2 - criar módulo IAM |
| Single AZ (falha region) | Baixa | Alto | Documentado como aceitável para MVP |
| SSL staging não migrável | Média | Médio | Open Question - depende de domínio |

---

## Parte 4: Open Questions Report

### 4.1 Questões em Aberto

#### Q1: Certificados SSL/TLS (Domínio Necessário)

**Status:** 🔴 Bloqueante para HTTPS em produção

**Descrição:**
O setup atual de PROD (`setup-proxy.sh`) tenta usar Let's Encrypt:
```bash
sudo certbot certonly --standalone -n --agree-tos -m "$EMAIL" -d "$DOMAIN" --test-cert
```

**Problema:**
- `--test-cert` gera certificado de staging (não confiável)
- Domínio `solarway.test` é fictício
- Sem domínio real registrado, HTTPS não funcionará em produção

**Opções de Solução:**

| Opção | Descrição | Custo | Timeline |
|-------|-----------|-------|----------|
| A | Registrar domínio (ex: solarway.com.br) | R$ 40-100/ano | 1-2 dias |
| B | Usar domínio gratuito (freedns, duckdns) | Grátis | Imediato |
| C | Manter HTTP apenas (não recomendado) | - | - |
| D | Usar certificado auto-assinado | Grátis | Imediato |

**Recomendação:**
> **Opção B** (duckdns.org) para testes imediatos; **Opção A** para produção real.

**Ações Requeridas:**
1. Decisão do stakeholder sobre domínio
2. Se Opção B: Criar subdomínio `solarway.duckdns.org`
3. Atualizar `setup-proxy.sh` para remover `--test-cert` em produção
4. Documentar renovação automática (cronjob)

---

#### Q2: Backend Terraform Remoto

**Status:** 🔴 Bloqueante para equipe multi-desenvolvedor

**Descrição:**
State do Terraform está sendo salvo localmente (`terraform.tfstate`).

**Riscos:**
- Conflito de state entre desenvolvedores
- Perda de state se máquina local falhar
- Não há controle de concorrência (lock)

**Solução Técnica:**
```hcl
terraform {
  backend "s3" {
    bucket         = "solarway-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

**Implementação:** Fase 3 do Plano de Integração PROD.

---

#### Q3: Validação de Healthchecks

**Status:** 🟡 Melhoria recomendada

**Descrição:**
Scripts de setup (`setup-db.sh`) têm healthchecks básicos:
```bash
if ! nc -z localhost 3306; then
  echo "❌ MySQL nao responde"
  exit 1
fi
```

**Gaps:**
- Sem healthcheck HTTP (apenas TCP)
- Sem retry com exponential backoff
- Sem integração com AWS CloudWatch

**Recomendação:**
Criar script `healthcheck.sh` unificado com:
1. Verificação de portas TCP
2. Verificação de endpoints HTTP
3. Retry com backoff
4. Métricas para CloudWatch (opcional)

---

#### Q4: Backup e Disaster Recovery

**Status:** 🟡 Não implementado

**Descrição:**
Não há estratégia documentada para:
- Backup do banco de dados MySQL
- Backup dos workflows n8n
- Backup do state Terraform
- Plano de recuperação de desastres

**Recomendação:**
Implementar:
1. Snapshots EBS automatizados para EC2 com DB
2. Exportação periódica dos workflows n8n para S3
3. Versionamento do state Terraform
4. Documento `DISASTER_RECOVERY.md`

---

#### Q5: Monitoramento e Observabilidade

**Status:** 🟡 Não implementado

**Descrição:**
Infraestrutura atual não possui:
- CloudWatch Dashboard
- Alarmes de métricas (CPU, memória, disco)
- Centralização de logs
- Distributed tracing

**Recomendação (MVP):**
1. Configurar CloudWatch agent nas EC2
2. Criar dashboard básico (CPU, memória, Network)
3. Alarme para CPU > 80%
4. SSM Session Logs habilitados

---

### 4.2 Dependências Externas

| Dependência | Status | Criticidade | Contato/Owner |
|-------------|--------|-------------|---------------|
| Domínio DNS | 🔴 Pendente | Alta | Stakeholder/Cliente |
| AWS Account | 🟢 Configurado | Alta | Lab AWS Academy |
| GitHub Packages | 🟢 Funcional | Alta | GitHub |
| GitHub Actions (OIDC) | 🟡 Não configurado | Média | Infra Team |
| Let's Encrypt | 🟢 Funcional | Média | Let's Encrypt |
| DuckDNS (opcional) | 🟡 Não configurado | Baixa | Infra Team |

---

### 4.3 Checklist de Decisões Pendentes

- [ ] **Domínio:** Qual domínio será usado em produção?
- [ ] **SSL:** Aguardar domínio real ou usar staging/self-signed?
- [ ] **Backup:** Frequência de snapshots EBS aceitável?
- [ ] **CI/CD:** Prioridade para GitHub Actions vs. deploy local?
- [ ] **Multi-AZ:** Necessário para MVP ou aceitável single-AZ?

---

## Anexos

### Anexo A: Comandos de Verificação Rápida

```bash
# Verificar SSM connectivity
aws ssm start-session --target <instance-id>

# Verificar estado do Terraform
terraform state list

# Verificar health do proxy
curl http://<nginx-ip>/health

# Verificar variáveis de ambiente em uma EC2
aws ssm send-command \
  --instance-ids <instance-id> \
  --document-name "AWS-RunShellScript" \
  --parameters commands=["cat /tmp/solarway/.env"]

# Verificar NAT routing
traceroute -n 8.8.8.8  # De uma EC2 privada
```

### Anexo B: Estrutura de Arquivos Esperada

```
terraform/environments/prod/
├── main.tf
├── deploy.tf
├── variables.tf
├── outputs.tf
├── provider.tf
├── backend.tf              # NOVO: Configuração S3 backend
├── terraform.tfvars        # NOVO: Valores sensíveis (não commitado)
├── templates/              # VERIFICAR: Deve existir
│   ├── env.db.tmpl
│   ├── env.backend.tmpl
│   ├── env.frontend.tmpl
│   └── env.bot.tmpl
└── scripts/
    ├── deploy-prod.ps1
    ├── setup-backend.sh
    ├── setup-bot.sh
    ├── setup-db.sh
    ├── setup-frontend.sh
    └── setup-proxy.sh
```

### Anexo C: Referências

- [AWS SSM Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Let's Encrypt Staging](https://letsencrypt.org/docs/staging-environment/)
- [DuckDNS Free DNS](https://www.duckdns.org/)

### Anexo D: Artefatos de Controle de Execução

Este anexo define o que são e como manter artefatos de controle de execução no projeto Solarway.

#### D.1 Definição

**Artefato de Controle de Execução** é qualquer documento que:
- Determina a ordem de execução de operações
- Especifica parâmetros de entrada obrigatórios
- Define critérios de sucesso/falha
- É usado como referência durante execuções reais

#### D.2 Lista de Artefatos de Controle no Solarway

| Artefato | Tipo | Atualizado em Último Commit? | Dono |
|----------|------|------------------------------|------|
| `README.md` | Instrucional | ⚠️ Verificar | Equipe |
| `.env.example` | Contrato | ⚠️ Verificar | Infra |
| `INFRA_PLAN.md` | Arquitetural | ⚠️ Verificar | Infra |
| `services/*/README.md` | Operacional | ⚠️ Verificar | Dev + Infra |
| `scripts/*/*.sh` | Executável | ✅ Sim | Infra |
| `docker-compose.yml` | Executável | ✅ Sim | Dev |

#### D.3 Processo de Atualização

Quando um desenvolvedor altera código, deve perguntar:

1. **Esta mudança altera alguma variável de ambiente?**
   - → Atualizar `.env.example`
   - → Atualizar `services/*/README.md` que usam esta var

2. **Esta mudança altera ordem de execução?**
   - → Atualizar `README.md` raiz
   - → Atualizar `INFRA_PLAN.md` se afeta arquitetura

3. **Esta mudança cria novo serviço?**
   - → Criar `services/novo/README.md` seguindo template
   - → Atualizar `README.md` raiz com novo serviço
   - → Atualizar `INFRA_PLAN.md` se afeta infra

4. **Esta mudança altera IAM/network/segurança?**
   - → Atualizar `INFRA_PLAN.md`
   - → Documentar em `IMPLEMENTATION_PLAN.md`

#### D.4 Script de Validação (Proposta)

```powershell
# validate-docs.ps1 - Verifica integridade documentação
$errors = @()

# Verifica se paths em README existem
$readme = Get-Content README.md
$readme | Select-String "scripts/.*\.ps1" | ForEach-Object {
    $path = $_.Matches[0].Value
    if (-not (Test-Path $path)) {
        $errors += "Path não encontrado: $path"
    }
}

# Verifica se vars em .env.example são usadas em algum compose
$envVars = Get-Content .env.example | Select-String "^[A-Z]" | ForEach-Object { $_.Line.Split('=')[0] }
$composes = Get-ChildItem -Recurse docker-compose.yml
foreach ($var in $envVars) {
    $used = $composes | Select-String "\${$var}" -Quiet
    if (-not $used) {
        $errors += "Variável $var não encontrada em nenhum docker-compose.yml"
    }
}

if ($errors.Count -gt 0) {
    Write-Host "ERROS DE DOCUMENTAÇÃO:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" }
    exit 1
} else {
    Write-Host "Documentação validada com sucesso!" -ForegroundColor Green
}
```

---

## Histórico de Revisões

| Versão | Data | Autor | Alterações |
|--------|------|-------|------------|
| 1.0 | 2026-04-17 | Claude Code | Criação inicial do documento |
| 1.1 | 2026-04-17 | Claude Code | Adicionada Parte 0 sobre Documentação como Artefato de Controle de Execução; adicionado Anexo D sobre artefatos de controle |

---

*Fim do Relatório*
