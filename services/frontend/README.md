# Infraestrutura de Frontend

Este diretório separa e isola a orquestração do cliente gráfico, dividindo o ecossistema de acesso corporativo e institucional.

## Estrutura Atual

- **`institucional-website/`**: Manifesto responsável por empacotar e disponibilizar o Web App de Landpage / Apresentação.
- **`management-system/`**: Manifesto direcionado a prover o Painel Administrativo do sistema, requerendo conectividade direta de consumo por APIs ao Backend para autenticação e gestão de dados sensíveis.

---

## Requisitos de Build das Imagens UI

Ao invés de carregar diretórios fontes inteiros e NodeModules nos ambientes de nuvem, esses composes puxam diretamente as imagens de frontends previamente cacheadas e montadas (ex: `raniersptech/management-system`).

Para alimentar sua infraestrutura atualizada de Frontend aqui:

1. Vá até o repositório de código fonte do frontend respectivo (ex: `management-system/`);
2. Verifique se as variáveis locais nas fases de build estão devidamente configuradas;
3. Builde de forma nativa e impulsione para registry:
   ```bash
   docker build -t raniersptech/management-system:latest .
   docker push raniersptech/management-system:latest
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

A infraestrutura definirá as portas mapeadas (ex: porta `8080`, ou `8081` do host para o `3000` do client interno), ligando-os na rede trans-arquitetural referenciada como `solarize_network`.

> **⚠️ Atenção a Integração**: Os frontends orquestrados através desses containers buscam chamadas HTTP para o Backend atráves do DNS interno (ex: apontamentos diretos usando o proxy local ou o IP público, dependendo da variável de ambiente setada na pipeline React). Para chamadas Server-Side, garanta a dependência contínua aos construtores da `solarize_network`.
