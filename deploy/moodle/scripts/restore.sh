#!/usr/bin/env bash
set -euo pipefail

# Restaure une sauvegarde (base de données + moodledata) produite par backup.sh.
# Usage : ./scripts/restore.sh <db_backup.sql.gz> <moodledata_backup.tar.gz>

cd "$(dirname "$0")/.."
set -a; source .env; set +a

DB_BACKUP="${1:?Fournir le fichier de dump SQL (.sql.gz)}"
DATA_BACKUP="${2:?Fournir l'archive moodledata (.tar.gz)}"

echo "ATTENTION : ceci va écraser la base de données et les données Moodle actuelles."
read -rp "Continuer ? (oui/non) " CONFIRM
[ "$CONFIRM" = "oui" ] || { echo "Annulé."; exit 1; }

echo "Arrêt de Moodle et du cron ..."
docker compose stop moodle moodle-cron

echo "Restauration de la base de données ..."
gunzip -c "$DB_BACKUP" | docker compose exec -T mariadb \
  mysql -u root -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"

echo "Restauration de moodledata ..."
DATA_BACKUP_DIR="$(cd "$(dirname "$DATA_BACKUP")" && pwd)"
DATA_BACKUP_FILE="$(basename "$DATA_BACKUP")"
docker run --rm \
  --volumes-from "$(docker compose ps -q moodle)" \
  -v "$DATA_BACKUP_DIR:/backup" \
  alpine \
  sh -c "rm -rf /bitnami/moodledata/* && tar xzf /backup/$DATA_BACKUP_FILE -C /bitnami"

echo "Redémarrage de Moodle ..."
docker compose start moodle moodle-cron

echo "Restauration terminée."
