# Estratégia Futura: Subdomínios e SSL (HTTPS)

Este documento descreve como migrar da atual arquitetura baseada em portas para uma arquitetura baseada em subdomínios utilizando a porta 80/443 para todos os serviços, além de implementar SSL automático com Let's Encrypt.

## 1. Subdomínios Dinâmicos com `nip.io`

O `nip.io` é um serviço de DNS "wildcard" gratuito que permite criar subdomínios apontando para um IP sem configurar nada no provedor de DNS.

**Mapeamento Sugerido:**
- **Sistema de Gestão**: `gestao.[IP-DA-AWS].nip.io`
- **Site Institucional**: `institucional.[IP-DA-AWS].nip.io`
- **n8n**: `n8n.[IP-DA-AWS].nip.io`
- **WAHA**: `waha.[IP-DA-AWS].nip.io`

### Exemplo de Configuração Nginx (Subdomínios)

```nginx
# Exemplo para o n8n via Subdomínio na Porta 80
server {
    listen 80;
    server_name n8n.*.nip.io;

    location / {
        proxy_pass http://bot-n8n:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 2. Implementação de SSL (Let's Encrypt)

Para rodar com HTTPS na AWS utilizando Docker, a forma mais limpa é usar o container do Certbot.

### Passo 1: Preparar o Nginx para o Desafio do Certbot
Adicione este bloco ao seu `server` (porta 80) no `nginx.conf`:

```nginx
location ^~ /.well-known/acme-challenge/ {
    root /var/www/certbot;
}
```

### Passo 2: Executar o Certbot via Docker
Rode o seguinte comando na sua instância EC2:

```bash
docker run -it --rm --name certbot \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  certbot/certbot certonly --webroot \
  -w /var/www/certbot -d n8n.SUA-URL-NIP.io
```

### Passo 3: Configurar o Nginx para usar os Certificados
Após gerar os certificados, altere o `nginx.conf` para escutar na porta 443:

```nginx
server {
    listen 443 ssl;
    server_name n8n.*.nip.io;

    ssl_certificate /etc/letsencrypt/live/n8n.SUA-URL-NIP.io/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/n8n.SUA-URL-NIP.io/privkey.pem;

    location / {
        proxy_pass http://bot-n8n:5678;
    }
}
```

## 3. Vantagens desta Abordagem
1. **Segurança**: Apenas as portas 80 e 443 precisam ficar abertas no Security Group da AWS.
2. **Profissionalismo**: URLs amigáveis sem números de porta expostos.
3. **Escalabilidade**: Fácil adicionar novos microserviços apenas criando novos blocos `server` no Nginx.
