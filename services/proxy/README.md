# Proxy Reverso Central (Nginx)

Ponto de entrada único da aplicação Solarway, simulando localmente o comportamento da VM pública `ec2_nginx` na AWS.

## Função

O proxy central é um **roteador puro**: recebe o tráfego e encaminha para o container de frontend correto. Não duplica lógica de `/api/` — cada frontend já tem seu próprio Nginx interno que cuida disso via `BACKEND_URL`.

---

## Arquitetura

```
Internet / Browser
    │
    ▼
nginx-proxy (porta 80/443)
    │
    ├── :80  → management-system:80   (Nginx próprio do container → /api/ → backend)
    └── :81  → institutional-website:80 (Nginx próprio do container → /api/ → backend)
```

---

## Arquivos

| Arquivo | Ambiente | Descrição |
|---------|----------|-----------|
| `nginx.conf` | Local | Roteador puro com nomes de container Docker |
| `nginx.conf.template` | Produção AWS | Template com IPs privados da VPC via `envsubst` |
| `docker-compose.yml` | Local | Sobe o `nginx:alpine` nas portas 80 e 81 |

---

## Acesso Local

| URL | Serviço |
|-----|---------|
| `http://localhost/` | Management System |
| `http://localhost:81/` | Institucional Website |
| `http://localhost/health` | Healthcheck |

Subir o proxy manualmente:
```bash
cd services/proxy
docker compose --env-file ../../.env up -d
```

O `setup-local.ps1` / `setup-local.sh` sobe o proxy automaticamente como última etapa.

---

## Produção AWS (`nginx.conf.template`)

O `setup-proxy.sh` processa o template via `envsubst` com as seguintes variáveis:

| Variável | Descrição |
|----------|-----------|
| `MANAGEMENT_PRIVATE_IP` | IP privado da VM `frontend-1` na VPC |
| `INSTITUCIONAL_PRIVATE_IP` | IP privado da VM `frontend-2` na VPC |
| `BACKEND_PRIVATE_IP` | IP privado da VM de backend (reservado para uso futuro) |

Essas variáveis são injetadas automaticamente pelo `null_resource.nginx_deploy` no Terraform.

---

## Roadmap HTTPS (Let's Encrypt)

> [!NOTE]
> Implementar após validação do deploy HTTP na AWS. Requer domínio registrado.

**Mudanças planejadas:**
1. `nginx.conf.template` ganha dois blocos: `:80` (redirect 301 → `:443`) e `:443` (SSL)
2. `setup-proxy.sh` instala Certbot e emite certificado:
   ```bash
   sudo certbot certonly --standalone -d ${DOMAIN} --non-interactive --agree-tos -m ${ADMIN_EMAIL}
   ```
3. Novas variáveis no `.env`: `DOMAIN` e `ADMIN_EMAIL`
4. Renovação automática via `cron`: `certbot renew --quiet`

**Portas necessárias no Security Group AWS** (já configuradas no Terraform):
- `:80` TCP — para o challenge HTTP-01 do Let's Encrypt e redirect
- `:443` TCP — tráfego HTTPS

> [!WARNING]
> Durante a emissão do certificado, o Nginx **não pode estar rodando na porta 80** (Certbot usa `--standalone` que abre seu próprio servidor). O `setup-proxy.sh` para o container antes de emitir e reinicia após.
