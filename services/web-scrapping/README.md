# Web Scrapping — Serviço de Atualização de Preços

Este serviço é responsável por atualizar automaticamente os preços dos materiais cadastrados no banco de dados, realizando scraping nas páginas de produto do **Mercado Livre**.

## Arquitetura

- **Tipo**: Batch Job (executa, conclui e repete)
- **Imagem**: `ghcr.io/projeto-de-extensao-grupo-06/web-scrapping:latest`
- **Frequência**: A cada **24 horas** (loop infinito com `sleep 86400`)
- **Browser engine**: Playwright + Chromium (headless)
- **Rede**: `storage_network` (conecta-se diretamente ao `mysql-db`)

---

## Como Funciona

```
[Início do ciclo]
      │
      ▼
Lê todos os registros da tabela `material_url`
  (em batches de 20, via cursor)
      │
      ▼
Para cada URL:
  ├── Detecta o domínio (ex: "produto.mercadolivre.com.br")
  ├── Aplica a estratégia registrada para aquele domínio
  │     └── Busca o preço com o seletor `.andes-money-amount__fraction`
  ├── Compara com o preço atual no banco
  └── Salva somente se o preço mudou
      │
      ▼
Aguarda 24h → repete
```

### Estratégias Registradas

| Domínio | Estratégia | Seletor CSS |
|---------|-----------|-------------|
| `produto.mercadolivre.com.br` | `mercado_livre_strategy` | `.andes-money-amount__fraction` + `.andes-money-amount__cents` |

> [!NOTE]
> URLs cujo domínio **não possui estratégia registrada** são puladas com o log `[⏭] SKIPPED`.
> Isso significa que as URLs de fichas técnicas (PDFs de fornecedores) são ignoradas com segurança.

---

## Variáveis de Ambiente

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `DB_HOST` | Host do MySQL (nome do container na rede Docker) | `mysql-db` |
| `DB_PORT` | Porta interna do MySQL | `3306` |
| `DB_NAME` | Nome do banco de dados | `solarway` |
| `DB_USER` | Usuário do banco | `${DB_USERNAME}` do `.env` |
| `DB_PASSWORD` | Senha do banco | `${DB_PASSWORD}` do `.env` |

> [!IMPORTANT]
> A variável de ambiente é `DB_USER` (não `DB_USERNAME`). O mapeamento é feito no `docker-compose.yml`: `DB_USER: ${DB_USERNAME}`.

---

## URLs Cadastradas no Banco (`material_url`)

Os registros do Mercado Livre na tabela `material_url` usam o formato de **anúncio direto**:

```
https://produto.mercadolivre.com.br/MLB-XXXXXXX
```

> [!WARNING]
> **Não use** o formato de catálogo `/p/MLB...` — esses IDs são reutilizados pelo Mercado Livre e podem apontar para produtos incorretos ou expirados.

| ID | Material | URL (MLB) | Preço inicial |
|----|----------|-----------|---------------|
| 5 | Painel Solar 550W | `MLB-4289430353` | R$ 820,00 |
| 6 | Inversor On-Grid 5kW | `MLB-5387656668` | R$ 2.999,00 |
| 7 | Cabo Solar 6mm | `MLB-4939530756` | R$ 285,00 |
| 8 | Bateria LiFePO4 5kWh 48V | `MLB-3927049001` | R$ 5.975,00 |
| 9 | Estrutura Telhado Cerâmico | `MLB-1943499077` | R$ 417,55 |

---

## Iniciando o Serviço

O serviço é iniciado automaticamente pelos scripts de setup (`setup-local.ps1` e `setup-qa.sh`). Para iniciar manualmente:

```bash
# A partir da raiz do docker-composes/
cd services/web-scrapping
docker compose --env-file ../../.env up -d
```

Para acompanhar os logs em tempo real:

```bash
docker logs -f web-scrapping-scheduler
```

Para forçar uma execução imediata (sem aguardar as 24h):

```bash
docker restart web-scrapping-scheduler
```

---

## Monitoramento — Saída Esperada nos Logs

```
[web-scrapping] 2026-04-12 10:00:00 - Iniciando raspagem...

  ____   ___  _        _    ____  __        ___  __   __
 / ___| / _ \| |      / \  |  _ \ \ \      / / \ \ \ / /
 \___ \| | | | |     / _ \ | |_) | \ \ /\ / / _ \ \ V /
  ___) | |_| | |___ / ___ \|  _ <   \ V  V / ___ \ | |
 |____/ \___/|_____/_/   \_\_| \_\   \_/\_/_/   \_\|_|

         W E B   S C R A P I N G   B A T C H

🚀 [SYSTEM ALERT] Initiating web scraping batch process. Please wait...

⚙️  [SYSTEM INIT] Scanning for scraping strategies...
   [+] PLUGGED IN | mercado_livre_strategy

▶ [BATCH START] Fetching next batch (Cursor: 0)...
⚙️  Processing 9 URLs in the current batch...

    [⏭] SKIPPED   | solarcenter.com     | No strategy found | https://...
    [⏭] SKIPPED   | painelforte.com.br  | No strategy found | https://...
    [✓] PROCESSED  | produto.mercadolivre| Price: 820.0 -> 815.0 | https://...

💾 [DATABASE] Saving 1 updated records...

✅ [SUCCESS] Batch processing finished successfully!

[web-scrapping] 2026-04-12 10:00:45 - Proxima execucao em 24h.
```
