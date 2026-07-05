#!/usr/bin/env bash
set -euo pipefail

# Sauvegarde la base de données MariaDB et les données Moodle (moodledata).
# À planifier via crontab, ex :
#   0 3 * * * /opt/moodle-lxp/scripts/backup.sh >> /var/log/moodle-backup.log 2>&1

cd "$(dirname "$0")/.."
set -a; source .env; set +a

BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "[$TIMESTAMP] Dump de la base de données ..."
docker compose exec -T mariadb mysqldump \
  -u root -p"$MARIADB_ROOT_PASSWORD" \
  --single-transaction --quick --lock-tables=false \
  "$MARIADB_DATABASE" | gzip > "$BACKUP_DIR/db_${TIMESTAMP}.sql.gz"

echo "[$TIMESTAMP] Archivage de moodledata ..."
docker run --rm \
  --volumes-from "$(docker compose ps -q moodle)" \
  -v "$(pwd)/$BACKUP_DIR:/backup" \
  alpine \
  tar czf "/backup/moodledata_${TIMESTAMP}.tar.gz" -C /bitnami moodledata

echo "[$TIMESTAMP] Suppression des sauvegardes de plus de $RETENTION_DAYS jours ..."
find "$BACKUP_DIR" -type f -name "*.gz" -mtime "+$RETENTION_DAYS" -delete

echo "[$TIMESTAMP] Sauvegarde terminée dans $BACKUP_DIR"
