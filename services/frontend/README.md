# Infraestrutura de Frontend

Este diretório separa e isola a orquestração do cliente gráfico, dividindo o ecossistema de acesso corporativo e institucional.

## Estrutura Atual

- **`management-system/`**: Sistema gerencial privado (painel de controle). Requer autenticação e acesso contínuo à API do backend.
- **`institucional-website/`**: Site institucional de apresentação da Solarway.

---

## Arquitetura de Proxy

Cada container de frontend **já possui seu próprio Nginx interno** (`nginx.conf.template`) que:
1. Serve os arquivos estáticos do React (`location /`)
2. Proxia chamadas de API para o backend (`location /api/ → ${BACKEND_URL}`)

Esses containers são acessados **indiretamente** através do proxy central (`services/proxy/`), que atua como ponto de entrada único.

```
Browser
  ├── localhost:80  → nginx-proxy → management-system:80 → /api/ → backend-service:8000
  └── localhost:81  → nginx-proxy → institutional-website:80 → /api/ → backend-service:8000
```

> [!NOTE]
> Em produção (AWS), o `nginx-proxy` (ec2_nginx) roteia para os IPs privados de cada VM de frontend.
> `BACKEND_URL` nos containers dos frontends aponta para o IP privado da VM do backend.

---

## Requisitos de Build das Imagens (GitHub Packages)

As imagens são hospedadas no **GHCR** sob `ghcr.io/projeto-de-extensao-grupo-06/`.

```bash
# Autenticação
echo $GITHUB_ACCESS_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Build e push (exemplo management-system)
docker build -t ghcr.io/projeto-de-extensao-grupo-06/management-system:latest .
docker push ghcr.io/projeto-de-extensao-grupo-06/management-system:latest
```

---

## Variáveis de Ambiente

| Variável | Descrição | Padrão local |
|----------|-----------|-------------|
| `BACKEND_URL` | URL do backend para o Nginx interno | `http://backend-service:8000` |
| `PORT_MANAGEMENT_SYSTEM` | Porta exposta do management system | `8080` |
| `PORT_INSTITUCIONAL_WEBSITE` | Porta exposta do site institucional | `8081` |

> [!IMPORTANT]
> Em produção, `BACKEND_URL` deve apontar para o **IP privado** da VM do backend na VPC, ex: `http://10.0.3.x:8000`.

