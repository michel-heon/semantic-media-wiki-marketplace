#!/usr/bin/env bash
# packer/provisioners/04-install-mysql.sh
# Installation MySQL 8.x + configuration initiale + sécurisation
# ADR-613 — Architecture et Validation des Provisioners Packer
# ADR-616 — Blob Storage Azure comme Cache de Packages
#
# Variables d'environnement injectées par Packer (smw-vm.pkr.hcl) :
#   MYSQL_VERSION         — ex: 8.0
#   BLOB_STORAGE_BASE_URL — URL de base du cache blob (sans slash final)
#   SMW_LOG_FILE          — chemin du fichier de log
#
# ⚠️ Aucune version codée en dur dans ce script.
# ⚠️ Le mot de passe root MySQL est défini vide ici ; il SERA configuré
#    via cloud-init au premier démarrage (ADR-613, ADR-800).
set -euo pipefail

LOG_FILE="${SMW_LOG_FILE:-/var/log/smw-install.log}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "[04-install-mysql] Démarrage — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[04-install-mysql] MYSQL_VERSION=${MYSQL_VERSION}"
echo "[04-install-mysql] BLOB_STORAGE_BASE_URL=${BLOB_STORAGE_BASE_URL:-<non défini>}"
echo "============================================================"

# ---------------------------------------------------------------------------
# Fonction : download_package (ADR-616 — blob-first avec fallback)
# ---------------------------------------------------------------------------
download_package() {
    local package_name="${1}"
    local source_url="${2}"
    local output_file="${3}"

    if [[ -n "${BLOB_STORAGE_BASE_URL:-}" ]]; then
        local blob_url="${BLOB_STORAGE_BASE_URL}/${package_name}"
        echo ">>> Trying blob cache: ${blob_url}"
        if wget --spider --quiet "${blob_url}" 2>/dev/null; then
            echo ">>> Downloading from blob cache: ${blob_url}"
            wget -q "${blob_url}" -O "${output_file}"
            echo ">>> Downloaded from blob cache: ${package_name}"
            return 0
        else
            echo ">>> Blob not found, fallback to source: ${source_url}"
        fi
    fi

    echo ">>> Downloading from source: ${source_url}"
    wget -q "${source_url}" -O "${output_file}"
}

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1. Installation MySQL Server
# ---------------------------------------------------------------------------
echo "[04-install-mysql] Installation de MySQL ${MYSQL_VERSION}..."
apt-get install -y \
    "mysql-server-${MYSQL_VERSION}" \
    "mysql-client-${MYSQL_VERSION}"

# ---------------------------------------------------------------------------
# 2. Démarrage temporaire de MySQL pour la configuration initiale
# ---------------------------------------------------------------------------
echo "[04-install-mysql] Démarrage temporaire de MySQL..."
systemctl start mysql

# Attendre que MySQL soit prêt
MAX_TRIES=30
TRIES=0
while ! mysqladmin ping --silent 2>/dev/null; do
    TRIES=$(( TRIES + 1 ))
    if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
        echo "[04-install-mysql] ERREUR: MySQL n'a pas démarré après ${MAX_TRIES} tentatives"
        exit 1
    fi
    echo "[04-install-mysql] Attente MySQL... (tentative ${TRIES}/${MAX_TRIES})"
    sleep 2
done
echo "[04-install-mysql] MySQL prêt."

# ---------------------------------------------------------------------------
# 3. Sécurisation MySQL (équivalent mysql_secure_installation)
# ---------------------------------------------------------------------------
echo "[04-install-mysql] Sécurisation MySQL..."
mysql --user=root <<'SQL'
-- Supprimer les utilisateurs anonymes
DELETE FROM mysql.user WHERE User='';

-- Désactiver l'accès root à distance (loopback uniquement, ADR-200)
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Supprimer la base test
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';

-- Créer la base mediawiki (vide, configurée au 1er boot via cloud-init)
CREATE DATABASE IF NOT EXISTS mediawiki CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Créer l'utilisateur mediawiki avec un mot de passe provisoire vide
-- ⚠️ Le mot de passe RÉEL sera défini au premier boot via cloud-init (ADR-800)
CREATE USER IF NOT EXISTS 'mediawiki'@'localhost' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON mediawiki.* TO 'mediawiki'@'localhost';

FLUSH PRIVILEGES;
SQL

# ---------------------------------------------------------------------------
# 4. Configuration du datadir vers /data/mysql (ADR-613)
# ---------------------------------------------------------------------------
echo "[04-install-mysql] Configuration du datadir /data/mysql..."
systemctl stop mysql

# Copie des données initiales vers /data/mysql
if [[ -d /var/lib/mysql ]]; then
    cp -a /var/lib/mysql/. /data/mysql/
fi
chown -R mysql:mysql /data/mysql
chmod 750 /data/mysql

# Mise à jour de la configuration MySQL
cat > /etc/mysql/mysql.conf.d/smw-datadir.cnf <<MYSQL_CNF
# Configuration SMW Marketplace — ADR-613
[mysqld]
datadir = /data/mysql
bind-address = 127.0.0.1
MYSQL_CNF

# Mettre à jour AppArmor si présent
if [[ -f /etc/apparmor.d/usr.sbin.mysqld ]]; then
    sed -i 's|/var/lib/mysql|/data/mysql|g' /etc/apparmor.d/usr.sbin.mysqld
    apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld || true
fi

# ---------------------------------------------------------------------------
# 5. Activation du service MySQL (démarrera au premier boot)
# ---------------------------------------------------------------------------
echo "[04-install-mysql] Activation du service mysql..."
systemctl enable mysql

echo "[04-install-mysql] Terminé — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"
