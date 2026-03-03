#!/bin/bash
# =========================================================================================
# Script Auxiliar para gerar o primeiro certificado Let's Encrypt usando a stack Docker
# =========================================================================================

# NOTA: Antes de rodar este script, configure o arquivo conf.d/app.conf com seus domínios 
# (removendo os comentários) e certifique-se de que os DNS apontam para o IP deste servidor.

# Substitua pelos seus domínios reais:
domains=(api.seudominio.com.br sistema.seudominio.com.br www.seudominio.com.br)
rsa_key_size=4096
data_path="./certbot"
email="[EMAIL_ADDRESS]" # Adicione um email real para receber avisos de expiração
staging=0 # Mude para 1 se estiver apenas testando para não estourar o limite de requisições da api do Let's Encrypt

if [ -d "$data_path" ]; then
  read -p "Já existe uma pasta de certificados em $data_path. Deseja substituir os atuais? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Fazendo download dos parâmetros de segurança recomendados para Nginx..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nodejs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo "### Download concluído."
fi

echo "### Gerando certificados falsos (dummy) provisórios para o Nginx conseguir ligar..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo "### Feito."

echo "### Iniciando o Nginx ..."
docker-compose up --force-recreate -d nginx
echo "### Nginx online."

echo "### Deletando certificados falsos (dummy)..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo "### Feito."

echo "### Solicitando os certificados REAIS originais para o Let's Encrypt..."
# Join domain names for the certbot command
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo "### Certificados gerados!"

echo "### Recarregando o Nginx com os novos certificados..."
docker-compose exec nginx nginx -s reload
echo "### Finalizado com Sucesso!"
