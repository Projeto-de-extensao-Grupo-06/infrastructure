# ☁️ Relatório de Diagnóstico de Infraestrutura - Mapeamento e Estratégia (Solarway Atualizado)

## 1. DIAGNÓSTICO GERAL DA ENGENHARIA

 A infraestrutura em nuvem do ecossistema Solarway encontra-se arquitetada de forma modular (VPC, EC2, S3), separando QA (Ambiente Single Node) de Produção (Alta Disponibilidade). Após as últimas vistorias e alinhamentos técnicos, foi traçado um plano rígido focado simultaneamente em **otimização matemática de custos (Cost-Saving)** e governança. 

Deixaremos gradativamente de depender do uso manual de chaves físicas e Bastions, e implementaremos a resolução do isolamento da rede adotando roteadores próprios (substituindo serviços caros de Cloud) e automações nativas no fluxo de containers do core de Bots (n8n), bem como a introdução simulada de proteções SSL no proxy.

**Nível de Maturidade Alvo**: Avançado (IaC customizado + Immutable Containers + OIDC CD Pipeline).

---

## 2. PROBLEMAS CRÍTICOS (P0) MITIGADOS

🔴 **P0.1: Ausência de Internet Outbound nas EC2 Privadas - RESOLVIDO PELA ESTRATÉGIA IAAS**
- **Sintoma Antigo**: As máquinas EC2 das subnets privadas tentariam instalar recursos nos scripts de user-data, estourando *timeout* pela ausência de rota para a internet (pois a adoção de um *Managed NAT Gateway* custaria caro para o escopo).
- **Adequação (Plano de Ação NAT IaaS)**: Absteremos do serviço pago. Ao invés disso, uma configuração Kernel (`net.ipv4.ip_forward=1`) e roteamento `iptables -t nat MASQUERADE` será injetada no script da máquina principal do **Nginx Proxy** (`public_subnet`). Com o atributo AWS `source_dest_check` desligado nela, a EC2 passará a rotear anonimamente todo o tráfego 0.0.0.0/0 vindo da subnet privada para fora, a custo zero.

🔴 **P0.2: Autenticação via Chave `.pem` exposta e Script Local**
- **Adequação (Plano Híbrido)**: Vamos tolerar temporariamente o uso de SSH Bastion com chave `.pem` exclusivametne na pipeline do Null_Resource para manter a execução local funcional, **MAS** embutiremos na base do Terraform o provisionamento Endpoints de Interface AWS e anotação do *IAM Instance Profile* contendo a credencial central de `AmazonSSMManagedInstanceCore`. Isso abrirá portas p/ substituição do SSH pelo Systems Manager seguro via Cloud, mitigando de forma final a infra.

🔴 **P0.3: Falta de Backend Remoto S3 e Lock de DB**
- **Adequação**: Mandatório o provisionamento de backend em ambiente compartilhado para não corromper o `.tfstate` na máquina de execução isolada atual.

---

## 3. MELHORIA NO PROXY: Criptografia HTTPS via Let's Encrypt (Simulação)

No estágio atual, expor porta HTTP lisa em produções é uma falha massiva. Porém, com a limitação presente de não possuirmos o domínio do DNS em repouso ativo, o deploy atual falharia numa verificação HTTP01 Challenge real.

- **Estratégia Adotada**: Implementaremos a mecânica padrão do Let's Encrypt usando a ferramenta `Certbot` através de processamento *Host-side Standalone* nos scripts do Proxy Nginx, abrindo os binds da `:443` no container. 
- **Simulação Ativa**: Até obtermos controle da URL final e apontarmos os registros Tipo A para a EC2 do Nginx, as requisições HTTPS e geração do TLS no setup vão incorporar testes temporários (ex: variáveis isoladas mockando hosts ou `certbot --staging`) para que o Terraform seja validado de ponta-a-ponta, prevenindo qualquer refatoração complexa mais tarde.

---

## 4. MELHORIA NOS BOTS: Imutabilidade do n8n via Docker Build

**Diagnóstico Antigo**: O ecossistema de Bot subia pelo compose a imagem pública padrão (`n8nio/n8n:latest`) e dependia de intervenção humana na UI para anexar credenciais e injetar fluxos. 

**Estratégia Adotada: Automação pela Carga Dinâmica (Nativa)**
- Transformaremos o contêiner dinâmico em uma estrutura *Deploy-Ready*.  
- Através de um `Dockerfile` customizado no sub-domínio `services/bot/n8n`, toda e qualquer modificação criada no dashboard pelos engenheiros Solarway será transposta em formato Json e encriptados diretamente via Carga no Build do contêiner.
- Quando o Setup de Produção rodar, ele não invocará apenas a imagem crua, executará o empacotamento com o comando interno de importação nativa da cli em sua subida atrelando as chaves: `n8n import:workflow --input` e `n8n import:credentials`. 

---

## 5. REVISÃO DO CD PIPELINE E ESTEIRA GOVERNADA

Os deploys futuros no Github Actions incorporarão essa topologia exata e engessada substituindo o `deploy-qa.ps1`:
1. **GitHub OIDC provider**: Auth temporal sem *AWS_ACCESS_KEY*.
2. **Revisão Dinâmica**: Regras severas para validar os outputs do Proxy NAT. 
3. O build nativo do N8n será antecipado nessa esteira de CI gerando novas imagens para Push no GHCR.

---

## 6. BACKLOG CONSOLIDADO (Priorizações de Tarefas Autorizadas)

| PRIORIDADE | Módulo / Esforço | Execução Autorizada |
|---|---|---|
| 🔴 **[P01]** | **Proxy Nat** | Aplicar configurações do Kernel de Masquerade IpTables no `setup-proxy.sh` + Redes de Envio Roteadas via Interface no `vpc/prod`. |
| 🔴 **[P02]** | **SSL Mock** | Instalar binários Certbot nos EC2 entrypoints provisionando certificado auto-assinado ou `staging`, ajustando nginx p/ listen 443. |
| 🟡 **[P03]** | **n8n Builder** | Elaborar o arquivo Dockerfile da image e substituir property no compose. Validar carga e pastas de credenciais nativas dentro do projeto. |
| 🟡 **[P04]** | **SSM / IAM** | Acoplar roles permissivas ao código TF sem afetar as redes nulas por connection. |
| 🟢 **[P05]** | **OIDC CI/CD** | Implementação tardia das lógicas .yml de actions aprovando os state locks de backend S3. |

# Planejamento Arquitetural: NAT IaaS, SSM, SSL e Automação n8n

Este plano expande o detalhamento da infraestrutura para integrar NAT Instance IaaS (cost-saving abolindo NAT Gateway gerenciado), provisionamento ágil de SSL via Let's Encrypt (Certbot), e automação de configuração progressiva da engine de bots N8N suportado por Native Image Building, visando total integração no Pipeline CD.

## User Review Required

> [!IMPORTANT]
> **Aprovação do Fluxo Completo**: As 4 fases abaixo interagem diretamente entre si. A mudança de HTTPS irá travar os domínios, você precisa confirmar que tem um domínio válido para uso atrelado ao DNS apontando para o IP de Produção antes que a esteira possa rodar com eficácia, caso contrário, o certbot falhará no TLS challenge.

## Proposed Changes

---

### Fase 1: NAT Instance e SSM Session Manager (Economia e Egress Seguro)

Tornaremos a EC2 do Nginx a via de rota de saída (`0.0.0.0/0`) da rede privada da VPC.
#### [MODIFY] [modules/ec2/variables.tf](file:///C:/Users/ranie/Desktop/sptech/2ano/projeto-extensao/docker-composes/terraform/modules/ec2/variables.tf)
Adicionar `source_dest_check` p/ desabilitar *anti-spoofing* provendo funções NAT nativas e expor `primary_network_interface_id` nos outputs.

#### [MODIFY] [modules/vpc/main.tf](file:///C:/Users/ranie/Desktop/sptech/2ano/projeto-extensao/docker-composes/terraform/modules/vpc/main.tf)
Criar uma Route Table independente "private" e isolar a sub-rede privada atribuindo o ID desta no Route Table Association.

#### [MODIFY] [environments/prod/main.tf](file:///C:/Users/ranie/Desktop/sptech/2ano/projeto-extensao/docker-composes/terraform/environments/prod/main.tf)
Roteamento explícito: O ENI do `ec2_nginx` torna-se a rota principal da sub-rede privada (`aws_route`). Desligar `source_dest_check` no módulo da proxy. 

#### [MODIFY] [setup-proxy.sh](file:///C:/Users/ranie/Desktop/sptech/2ano/projeto-extensao/docker-composes/scripts/setup/prod/setup-proxy.sh)
Habilitar a liberação Iptables MASQUERADE de roteador no host base do ubuntu, transformando ele no *jump-point* da internet out:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o eth0 -s 10.0.0.0/24 -j MASQUERADE
```

---

### Fase 2: Configurações de HTTPS (Let's Encrypt SSL/TLS)

Ao invés de adicionar complexidade com containers sidecar complexos que quebram o cache, operaremos de maneira pragmática executando o client local nativo (cerbot) rodando isolado sobre o host Ubuntu durante os provisionamentos da VM na Cloud, garantindo que o volume já contemple as chaves. 

#### [MODIFY] [setup-proxy.sh](file:///C:/Users/ranie/Desktop/sptech/2ano/projeto-extensao/docker-composes/scripts/setup/prod/setup-proxy.sh)
Interromper proxy port 80 em caso de primeira excução e gerar certificados automáticos por parâmetros em Standalone limitando bloqueios.  
```bash
# Iniciar Geração de Certificados
sudo apt-get install -y certbot
sudo certbot certonly --standalone -n --agree-tos -m "\${ADMIN_EMAIL}" -d "\${DOMAIN}"
```

#### [MODIFY] [proxy/docker-compose.yml](file:///C:/Users/ranie/Desktop/sptech/2ano/projeto-extensao/docker-composes/services/proxy/docker-compose.yml)
Abrir Porta `443:443` e montar as pastas restritas em read-only:
```yaml
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt:ro
```

#### [MODIFY] [proxy/nginx.conf.template](file:///C:/Users/ranie/Desktop/sptech/2ano/projeto-extensao/docker-composes/services/proxy/nginx.conf.template)
Transferir o tráfego 80 com `redirect 301 https://$host$request_uri;` e estruturar listeners para o 443 consumindo as diretrizes `ssl_certificate /etc/letsencrypt/live/xxx/fullchain.pem`.

---

### Fase 3: Image Build Nativo e Importação do n8n

Para não delegar as configurações operacionais para ações manuais ou API expostas, as workflows do cliente e definições sensíveis passarão a morar como "código" importado pelo Dockerfile usando Node/CLI interna nativamente no momento de subida. 

#### [NEW] `services/bot/n8n/Dockerfile` e Diretórios
Configuraremos repositório dedicado que contém seus scripts, empacotando os workflows salvos no projeto.
```dockerfile
FROM n8nio/n8n:latest
USER root
RUN mkdir -p /docker-entrypoint-init.d
COPY workflows/ /data/workflows/
COPY credentials/ /data/credentials/

# Script executado ANTES do N8N iniciar, que carrega as chaves via CLI param.
COPY init-import.sh /docker-entrypoint-init.d/
RUN chmod +x /docker-entrypoint-init.d/init-import.sh
USER node
```
A CLI nativa do N8N (`n8n import:workflow --input=/data/workflows/`) será engatilhada sempre que subir a instância, validando mutações dos objetos da nuvem usando as próprias variáveis do `.env` na runtime para plugar secrets que conectam as APIs da própria infraestrutura.

#### [MODIFY] [bot/docker-compose.yml](file:///C:/Users/ranie/Desktop/sptech/2ano/projeto-extensao/docker-composes/services/bot/docker-compose.yml)
Substituir a propriedade `image: n8nio/n8n:latest` estática por `build: ./n8n` para engatilhar as novas instâncias com base na runtime consolidada nativa.

## Open Questions

- *Nenhuma questão estrutural pendente. Fomos autorizados a simular/mockar o SSL na infra inicialmente e progredir utilizando a carga do JSON nativo no n8n. Tudo alinhado!*

## Verification Plan

### Validações
1. **Comprovação IaaS NAT**: Conectar na VPC de QA via Nginx p/ pingar serviços externos do Node Backend e validar se a Route funcionou via Nginx Forward. 
2. **Validar Certificados HTTPS**: Analisar a porta 443 do HealthCheck no domínio (ex: `https://meupainel.com/health`) observando handshake com validação Secure Issuer (`Let's Encrypt`). 
3. **Validar Importação N8N**: Subir ambiente BOT local e confirmar com API externa (`GET localhost:5678/api/v1/workflows`) se as automações inseridas dentro dos JSONs internos nasceram auto-provisionadas e ativas na inicialização limpa no banco SQlite do N8N.
