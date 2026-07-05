# Déploiement Moodle (LXP) — Docker sur VPS — campus.educsante.academy

Stack Docker Compose prête à l'emploi pour déployer Moodle en production :
MariaDB, Moodle (Bitnami), cron Moodle, Redis, Nginx (reverse proxy + TLS)
et Certbot (Let's Encrypt).

## Architecture

```
Internet ──▶ nginx (80/443) ──▶ moodle:8080 ──▶ mariadb:3306
                 │                    │
             certbot (SSL)      moodle-cron (tâches planifiées)
                                      │
                                    redis (cache)
```

## 1. Prérequis sur le VPS

- Ubuntu 22.04 LTS ou Debian 12, accès root/sudo par SSH.
- L'enregistrement DNS **A** `campus.educsante.academy` doit pointer vers
  l'IP publique du VPS (vérifier avec `dig campus.educsante.academy`).
- Au moins 2 vCPU / 4 Go RAM / 40 Go disque pour un usage modéré.

### Installation de Docker

```bash
sudo apt update && sudo apt upgrade -y
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"
# se reconnecter pour que le groupe docker soit pris en compte
```

### Pare-feu (ufw)

```bash
sudo apt install -y ufw
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### Protection SSH (fail2ban)

```bash
sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
```

## 2. Déploiement

```bash
sudo mkdir -p /opt/moodle-lxp
sudo chown "$USER":"$USER" /opt/moodle-lxp
# Copier le contenu de ce dossier deploy/moodle/ vers /opt/moodle-lxp sur le VPS
cd /opt/moodle-lxp

cp .env.example .env
nano .env   # renseigner tous les mots de passe, l'email, le SMTP, etc.

chmod +x scripts/*.sh
```

Démarrer la base de données, Moodle, le cron et Redis (sans nginx pour l'instant) :

```bash
docker compose up -d mariadb redis moodle moodle-cron
docker compose logs -f moodle   # attendre la fin de l'installation initiale
```

Obtenir le certificat SSL et démarrer nginx (opération unique) :

```bash
./scripts/init-letsencrypt.sh
```

Vérifier que le site répond :

```bash
curl -I https://campus.educsante.academy
```

Se connecter sur `https://campus.educsante.academy` avec le compte admin
défini dans `.env` (`MOODLE_ADMIN_USER` / `MOODLE_ADMIN_PASSWORD`).

## 3. Sauvegardes automatiques

Ajouter au crontab root (`crontab -e`) :

```
0 3 * * * /opt/moodle-lxp/scripts/backup.sh >> /var/log/moodle-backup.log 2>&1
```

Les sauvegardes (dump SQL + archive moodledata) sont écrites dans
`BACKUP_DIR` (par défaut `./backups`) et purgées après `BACKUP_RETENTION_DAYS`
jours (par défaut 7). Copier régulièrement ce dossier vers un stockage
externe (autre VPS, S3, etc.).

Restauration :

```bash
./scripts/restore.sh backups/db_20260705_030000.sql.gz backups/moodledata_20260705_030000.tar.gz
```

## 4. Renouvellement SSL

Géré automatiquement par le service `certbot` (tentative de renouvellement
toutes les 12h, `certbot` ne renouvelle réellement qu'à moins de 30 jours de
l'expiration). Vérifier manuellement si besoin :

```bash
docker compose run --rm certbot renew --dry-run
```

## 5. Mise à jour de Moodle

```bash
./scripts/backup.sh                       # sauvegarde avant toute mise à jour
docker compose pull moodle moodle-cron
docker compose up -d moodle moodle-cron
docker compose exec moodle php /opt/bitnami/moodle/admin/cli/upgrade.php --non-interactive
```

## 6. Checklist finale

- [ ] `dig campus.educsante.academy` renvoie bien l'IP du VPS
- [ ] `https://campus.educsante.academy` charge Moodle avec un cadenas valide
- [ ] Connexion admin fonctionnelle
- [ ] `docker compose ps` : tous les services `healthy` / `Up`
- [ ] Le cron Moodle tourne (`docker compose logs moodle-cron`)
- [ ] Une sauvegarde manuelle (`./scripts/backup.sh`) s'exécute sans erreur
- [ ] Le crontab de sauvegarde automatique est bien planifié
- [ ] Le renouvellement SSL (`certbot renew --dry-run`) réussit
- [ ] ufw n'autorise que 22/80/443
- [ ] Les emails de test (inscription, mot de passe oublié) sont bien reçus

## Fichiers

- `docker-compose.yml` — orchestration des services
- `.env.example` — variables d'environnement à copier en `.env`
- `nginx/conf.d/campus.educsante.academy.conf` — vhost HTTPS + sécurité
- `scripts/init-letsencrypt.sh` — obtention du premier certificat SSL
- `scripts/backup.sh` / `scripts/restore.sh` — sauvegarde et restauration
