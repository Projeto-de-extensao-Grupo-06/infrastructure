# Reverse Proxy (Nginx e Let's Encrypt)

Esta stack gerencia a recepção de tráfego web seguro. Ela opera como o ponto central para realizar SSL Termination e reencaminhar chamadas HTTPS para as aplicações internas.

A stack utiliza:

- **Nginx (Alpine)**: Load Balancer e Proxy Reverso.
- **Certbot (Let's Encrypt)**: Autenticação de domínios e geração automática de certificados SSL gratuitos.

---

## IMPORTANT: Restrições de Inicialização

A execução do comando `docker-compose up -d` de forma isolada nesta stack falhará se for a primeira inicialização ou se a execução ocorrer em ambiente local (localhost).

O serviço Nginx configurado via `config/app.conf` exige a pré-existência dos certificados TLS (*fullchain.pem* e *privkey.pem*) no disco. A persistência destes arquivos depende da execução prévia do Certbot. A comunicação inicial exige procedimentos específicos estabelecidos através do gateway Docker (`host-gateway`).

## Inicialização de Certificados SSL (Ambiente Cloud/AWS)

Para a primeira implantação em ambiente com IP público acessível:

1. Modifique os domínios mapeados nos blocos em `config/app.conf` referentes à sua aplicação (Ex: `api.seudominio.com.br`) e ajuste as portas expostas pelo host, se necessário.
2. Certifique-se de que os registros DNS (A Record) declarados em `app.conf` apontam para o IP Público da instância EC2 correspondente.
3. Edite o utilitário `init-letsencrypt.sh`: configure seu endereço de e-mail na variável `email` (necessário para notificações de expiração SSL) e declare seus domínios no vetor `domains=()`.
4. Conceda permissão de execução ao script: `chmod +x init-letsencrypt.sh`.
5. Execute a inicialização: `sudo ./init-letsencrypt.sh`.

Este procedimento acionará temporariamente os serviços necessários via Docker Compose para emissão dos certificados e, na sequência, deixará os serviços de Proxy executando em background (daemon).

## Testes em Ambiente Local (Docker/WSL)

A emissão via Let's Encrypt não é compatível com ambientes locais, pois requer exposição das portas HTTP para internet pública para a resposta ao acme-challenge.

Para testes locais:

1. Modifique a resolução de nomes (DNS) local editando o arquivo `hosts` do SO (No Windows: `C:\Windows\System32\drivers\etc\hosts`) apontando os domínios definidos para `127.0.0.1`.
2. Gere certificados privados autoassinados (Self-Signed) via utilitário openSSL no diretório apropriado. Isto permitirá ao Nginx subir em modo HTTPS sem emitir exceções de I/O.
3. Inicie os containers com `docker-compose up -d`.
