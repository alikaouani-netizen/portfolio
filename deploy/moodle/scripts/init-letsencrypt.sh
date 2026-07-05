#!/usr/bin/env bash
set -euo pipefail

# À exécuter UNE SEULE FOIS pour obtenir le premier certificat SSL Let's Encrypt.
# Prérequis : l'enregistrement DNS A "campus.educsante.academy" doit déjà
# pointer vers l'IP de ce VPS, et les ports 80/443 doivent être ouverts.
#
# Usage :
#   ./scripts/init-letsencrypt.sh          # certificat de production
#   ./scripts/init-letsencrypt.sh staging  # certificat de test (rate-limit Let's Encrypt évité)

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "Fichier .env introuvable. Copier .env.example vers .env et le renseigner d'abord." >&2
  exit 1
fi
set -a; source .env; set +a

DOMAIN="${MOODLE_DOMAIN:?MOODLE_DOMAIN manquant dans .env}"
EMAIL="${LETSENCRYPT_EMAIL:?LETSENCRYPT_EMAIL manquant dans .env}"
RSA_KEY_SIZE=4096

STAGING_ARG=""
if [ "${1:-}" = "staging" ]; then
  STAGING_ARG="--staging"
  echo "### Mode STAGING (certificat de test, non valide dans un navigateur)"
fi

echo "### 1/4 - Génération d'un certificat temporaire auto-signé pour $DOMAIN"
docker compose run --rm --entrypoint "sh -c '\
  mkdir -p /etc/letsencrypt/live/$DOMAIN && \
  openssl req -x509 -nodes -newkey rsa:$RSA_KEY_SIZE -days 1 \
    -keyout /etc/letsencrypt/live/$DOMAIN/privkey.pem \
    -out /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
    -subj /CN=localhost'" certbot

echo "### 2/4 - Démarrage de nginx avec le certificat temporaire"
docker compose up -d nginx

echo "### 3/4 - Suppression du certificat temporaire"
docker compose run --rm --entrypoint "sh -c '\
  rm -rf /etc/letsencrypt/live/$DOMAIN /etc/letsencrypt/archive/$DOMAIN /etc/letsencrypt/renewal/$DOMAIN.conf'" certbot

echo "### Demande du certificat définitif auprès de Let's Encrypt"
docker compose run --rm certbot certonly --webroot -w /var/www/certbot \
  $STAGING_ARG \
  --email "$EMAIL" \
  -d "$DOMAIN" \
  --rsa-key-size $RSA_KEY_SIZE \
  --agree-tos \
  --non-interactive \
  --force-renewal

echo "### 4/4 - Rechargement de nginx avec le certificat définitif"
docker compose exec nginx nginx -s reload

echo ""
echo "Terminé : https://$DOMAIN est maintenant servi avec un certificat Let's Encrypt valide."
echo "Le renouvellement automatique est géré par le service 'certbot' du docker-compose."
