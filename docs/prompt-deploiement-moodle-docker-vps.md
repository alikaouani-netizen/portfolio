# Prompt détaillé — Déploiement Moodle (LXP) via Docker sur VPS

> Domaine cible : **campus.educsante.academy**
> Usage : copier-coller ce prompt dans un assistant IA (ex. Claude Code) ou le donner
> à un administrateur système / DevOps pour exécuter le déploiement de bout en bout.

---

## Prompt à utiliser

```
Tu es un ingénieur DevOps expérimenté. Je veux déployer Moodle (utilisé comme
plateforme LXP) en production sur un VPS, entièrement conteneurisé avec Docker,
accessible via le nom de domaine campus.educsante.academy en HTTPS.

CONTEXTE
- VPS Linux (Ubuntu 22.04 LTS ou Debian 12), accès root via SSH.
- Le DNS du domaine educsante.academy est déjà géré (je créerai/vérifierai
  l'enregistrement A "campus" pointant vers l'IP du VPS).
- Objectif : une plateforme Moodle stable, sécurisée, sauvegardée et facile
  à maintenir/mettre à jour.

ARCHITECTURE ATTENDUE
- docker-compose avec au minimum les services suivants :
  1. moodle (image officielle bitnami/moodle ou Dockerfile custom basé sur
     une image PHP-FPM + Moodle téléchargé depuis git, au choix — argumenter
     le choix).
  2. mariadb (ou postgresql) pour la base de données, avec volume persistant.
  3. reverse proxy nginx (ou traefik) gérant le TLS.
  4. certbot (ou intégration Let's Encrypt native à traefik) pour un
     certificat SSL auto-renouvelé pour campus.educsante.academy.
  5. redis (optionnel mais recommandé) pour le cache de session Moodle.
  6. cron (le cron Moodle doit tourner toutes les minutes — soit un service
     dédié, soit une tâche planifiée sur l'hôte qui exec dans le conteneur).

ÉTAPES ATTENDUES DANS TA RÉPONSE
1. Préparation du VPS :
   - mise à jour système, création d'un utilisateur non-root avec sudo,
   - installation de Docker Engine + Docker Compose plugin,
   - configuration du pare-feu (ufw) : ouvrir seulement 22 (SSH), 80, 443,
   - installation et configuration de fail2ban pour SSH.
2. Arborescence du projet sur le VPS (ex. /opt/moodle-lxp/) :
   - docker-compose.yml
   - .env (variables sensibles : mots de passe DB, clés secrètes, etc.,
     jamais committées en clair)
   - nginx/ (conf reverse proxy + templates SSL)
   - moodledata/ (volume persistant hors du conteneur, permissions www-data)
3. Fichier docker-compose.yml complet et commenté avec :
   - réseaux Docker dédiés (frontend/backend séparés),
   - volumes nommés pour moodledata et la base de données,
   - variables d'environnement lues depuis .env,
   - healthchecks pour chaque service,
   - politique de redémarrage "unless-stopped".
4. Configuration Nginx (ou Traefik) :
   - vhost pour campus.educsante.academy,
   - redirection HTTP -> HTTPS,
   - headers de sécurité (HSTS, X-Frame-Options, X-Content-Type-Options,
     Referrer-Policy),
   - limites d'upload adaptées à Moodle (fichiers de cours volumineux),
   - proxy_pass vers le service moodle avec les bons timeouts.
5. Obtention du certificat SSL Let's Encrypt pour campus.educsante.academy
   (commande certbot ou config ACME Traefik) + vérification du renouvellement
   automatique (cron/systemd timer + test avec --dry-run).
6. Configuration Moodle (config.php) :
   - $CFG->wwwroot = 'https://campus.educsante.academy'
   - $CFG->dataroot pointant vers le volume persistant
   - configuration reverse proxy ($CFG->sslproxy = true, reverseproxy = true
     si applicable)
   - configuration cache Redis si utilisé
   - paramètres SMTP pour les emails (notifications, inscriptions)
7. Installation initiale de Moodle :
   - exécution du script CLI admin/cli/install.php (ou install_database.php)
     avec les bons paramètres (langue fr, nom du site, compte admin),
   - création du premier compte administrateur avec mot de passe fort,
   - configuration du cron Moodle (admin/cli/cron.php) via une tâche
     planifiée toutes les minutes.
8. Sauvegardes :
   - script de backup automatisé (dump mariadb + tar de moodledata),
   - rotation des sauvegardes (ex. 7 jours glissants),
   - envoi/copie vers un stockage externe (S3, autre VPS, etc.) si possible,
   - test de restauration documenté.
9. Sécurité complémentaire :
   - désactivation de l'accès root SSH par mot de passe (clé uniquement),
   - mise à jour automatique des paquets de sécurité (unattended-upgrades),
   - limitation du rate-limit sur la page de login Moodle (contre le
     bruteforce) au niveau Nginx,
   - scan de vulnérabilités basique (ex. docker scout / trivy sur les images).
10. Supervision / monitoring :
    - logs centralisés (docker logs + rotation via logrotate ou driver
      json-file avec max-size),
    - healthcheck externe (ex. uptime monitor sur https://campus.educsante.academy),
    - alerte en cas d'échec du renouvellement SSL ou du service down.
11. Procédure de mise à jour de Moodle :
    - étapes pour upgrader la version (backup avant, pull nouvelle image,
      admin/cli/upgrade.php, rollback possible).

LIVRABLES ATTENDUS
- Le contenu complet des fichiers : docker-compose.yml, .env.example,
  nginx/campus.educsante.academy.conf, config.php (extrait pertinent),
  script backup.sh, et un script d'installation initiale (setup.sh ou
  README d'exécution pas à pas).
- Un résumé des commandes à exécuter dans l'ordre, du premier accès SSH
  jusqu'à la plateforme accessible en HTTPS sur campus.educsante.academy
  avec le compte admin créé.
- Une checklist finale de vérification (SSL valide, cron actif, backup
  fonctionnel, headers de sécurité présents, accès admin OK).

CONTRAINTES
- Toutes les données sensibles (mots de passe, clés) doivent être dans un
  fichier .env non versionné, jamais en dur dans docker-compose.yml.
- Prévoir la montée en charge modérée (quelques centaines d'utilisateurs
  simultanés) sans sur-ingénierie inutile.
- Répondre en français, avec du code prêt à copier-coller et des
  commentaires expliquant les points non triviaux (pourquoi tel paramètre,
  tel choix d'image, etc.).
```

---

## Comment utiliser ce prompt

1. Copier le bloc de code ci-dessus tel quel.
2. Le coller au début d'une session avec un assistant IA capable d'exécuter
   des commandes (ex. Claude Code connecté en SSH au VPS, ou simplement pour
   générer les fichiers de configuration).
3. Adapter les points suivants avant exécution :
   - IP réelle du VPS et accès SSH,
   - adresse email pour Let's Encrypt (notifications d'expiration),
   - paramètres SMTP réels pour les emails Moodle,
   - taille de VPS (RAM/CPU/disque) selon le nombre d'utilisateurs attendu.
4. Valider chaque étape en environnement de test avant la mise en production
   sur campus.educsante.academy (idéalement un sous-domaine de staging au
   préalable, ex. staging.campus.educsante.academy).
