#!/usr/bin/env bash
# packer/provisioners/01-install-base.sh
# Installation de base : packages système, répertoires, locales, timezone
# ADR-613 — Architecture et Validation des Provisioners Packer
#
# Variables d'environnement injectées par Packer (smw-vm.pkr.hcl) :
#   SMW_LOG_FILE  — chemin du fichier de log (défaut: /var/log/smw-install.log)
#
# ⚠️ Aucune version codée en dur dans ce script.
set -euo pipefail

LOG_FILE="${SMW_LOG_FILE:-/var/log/smw-install.log}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "[01-install-base] Démarrage — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"

# ---------------------------------------------------------------------------
# 0. Désactiver unattended-upgrades et attendre la libération des verrous APT
#    Sur les images cloud Azure, cloud-init + unattended-upgrades tournent en
#    arrière-plan au démarrage et corrompent le cache APT si on lance apt trop tôt.
# ---------------------------------------------------------------------------
echo "[01-install-base] Désactivation des mises à jour automatiques (unattended-upgrades)..."
systemctl stop unattended-upgrades 2>/dev/null || true
systemctl disable unattended-upgrades 2>/dev/null || true
# Attendre la libération des 3 verrous APT possibles
echo "[01-install-base] Attente de la libération des verrous APT..."
for _lock in /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock; do
    while fuser "${_lock}" >/dev/null 2>&1; do
        echo "  Verrou ${_lock} occupé — attente 5s..."
        sleep 5
    done
done
echo "[01-install-base] Verrous APT libérés."

# ---------------------------------------------------------------------------
# 1. Mise à jour de l'index APT
# ---------------------------------------------------------------------------
echo "[01-install-base] Mise à jour des paquets APT..."
export DEBIAN_FRONTEND=noninteractive
# Activer universe explicitement (nécessaire sur images Azure Ubuntu 22.04
# où le format deb822 peut omettre universe/multiverse par défaut)
if grep -qE "^Types:" /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null; then
    sed -i 's/^Components: main restricted$/Components: main restricted universe multiverse/' \
        /etc/apt/sources.list.d/ubuntu.sources
fi
add-apt-repository -y universe 2>/dev/null || true
apt-get update -y

# ---------------------------------------------------------------------------
# 2. Installation des packages système de base
# ---------------------------------------------------------------------------
echo "[01-install-base] Installation des packages de base..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    wget \
    git \
    unzip \
    gnupg \
    lsb-release \
    software-properties-common \
    locales \
    tzdata \
    sudo \
    logrotate \
    cron \
    ufw

# ---------------------------------------------------------------------------
# 3. Locales et timezone (Canada/francophone)
# ---------------------------------------------------------------------------
echo "[01-install-base] Configuration des locales et timezone..."
locale-gen en_US.UTF-8 fr_CA.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
timedatectl set-timezone UTC

# ---------------------------------------------------------------------------
# 4. Création des répertoires de données (ADR-613)
# ---------------------------------------------------------------------------
echo "[01-install-base] Création des répertoires de données..."
mkdir -p /data/uploads
mkdir -p /data/mysql
mkdir -p /data/logs
mkdir -p /opt/mediawiki
mkdir -p /opt/smw-marketplace/scripts/firstboot

# Droits initiaux — seront ajustés par les provisioners suivants
chmod 750 /data/uploads /data/mysql /data/logs
chmod 755 /opt/mediawiki /opt/smw-marketplace

echo "[01-install-base] Terminé — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"
