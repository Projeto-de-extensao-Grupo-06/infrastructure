# Infraestrutura de Frontend

Este diretório separa e isola a orquestração do cliente gráfico, dividindo o ecossistema de acesso corporativo e institucional.

## Estrutura Atual

- **`institucional-website/`**: Manifesto responsável por empacotar e disponibilizar o Web App de Landpage / Apresentação.
- **`management-system/`**: Manifesto direcionado a prover o Painel Administrativo do sistema, requerendo conectividade direta de consumo por APIs ao Backend para autenticação e gestão de dados sensíveis.

---

## Requisitos de Build das Imagens UI (GitHub Packages)

Os frontends utilizam imagens hospedadas no **GHCR** para deploy rápido.

1. **Autenticação**:
   ```bash
   echo $GITHUB_ACCESS_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
   ```

2. **Build e Tag**:
   Vá até o repositório UI correspondente e execute:
   ```bash
   docker build -t ghcr.io/projeto-de-extensao-grupo-06/management-system:latest .
   # Repita para o institucional-website alterando a tag
   ```

3. **Push**:
   ```bash
   docker push ghcr.io/projeto-de-extensao-grupo-06/management-system:latest
   ```

---

## Instanciação de Containers e Serviços

Uma vez que as imagens estejam sincronizadas (seja recém publicadas após build, ou baixadas pelo servidor):

1. Acesse o domínio interno desejado;
2. Instancie o provisionamento de forma destacada (em detached mode):
   ```bash
   cd management-system
   docker-compose up -d
   ```
*(O mesmo princípio aplica-se ao `institucional-website`).*

A infraestrutura definirá as portas mapeadas (ex: porta `8080`, ou `8081` do host para o `3000` do client interno), ligando-os na rede trans-arquitetural referenciada como `solarway_network`.

> **⚠️ Atenção a Integração**: Os frontends orquestrados através desses containers buscam chamadas HTTP para o Backend atráves do DNS interno (ex: apontamentos diretos usando o proxy local ou o IP público, dependendo da variável de ambiente setada na pipeline React). Para chamadas Server-Side, garanta a dependência contínua aos construtores da `solarway_network`.
