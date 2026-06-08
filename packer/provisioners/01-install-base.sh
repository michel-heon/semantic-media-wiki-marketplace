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
# 1. Mise à jour de l'index APT + UPGRADE complet (ADR-804 / Issue #4 T5)
#    Politique Microsoft Marketplace 200.5.8 — l'image doit contenir tous
#    les patches de sécurité Ubuntu (zéro CVE CVSS3 ≥ 7.0).
#    Cause-racine du rejet de certification du 2026-06-02 :
#      USN-8284-1, USN-8292-1, USN-8293-1, USN-8306-1
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

echo "[01-install-base] [T5] apt-get upgrade — application des patches de sécurité..."
APT_OPTS=(-y \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold)
apt-get upgrade "${APT_OPTS[@]}"
apt-get dist-upgrade "${APT_OPTS[@]}"
apt-get autoremove -y
apt-get autoclean -y

# ---------------------------------------------------------------------------
# 2. Installation des packages système de base + Azure Linux Agent (T2)
#    Politique 200.3.3 — waagent ≥ 2.2.10 requis.
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
    ufw \
    walinuxagent

echo "[01-install-base] [T2] Validation waagent..."
WAAGENT_VERSION=$(waagent --version 2>&1 | head -n1 || echo "ABSENT")
echo "[01-install-base] waagent version : ${WAAGENT_VERSION}"
if ! command -v waagent >/dev/null 2>&1; then
    echo "[01-install-base] ❌ ERREUR : waagent introuvable (politique 200.3.3 violée)" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 2.b Validation des 4 USN bloquants (ADR-804 / Rapport 2026-06-18)
# ---------------------------------------------------------------------------
echo "[01-install-base] [T5] Vérification des versions de paquets USN..."
check_pkg_min_version() {
    local pkg="$1" min="$2"
    local current
    current=$(dpkg-query -W -f='${Version}' "${pkg}" 2>/dev/null || echo "")
    if [[ -z "${current}" ]]; then
        echo "[01-install-base]   ⚠ ${pkg} : non installé (skip)"
        return 0
    fi
    if dpkg --compare-versions "${current}" ge "${min}"; then
        echo "[01-install-base]   ✅ ${pkg} ${current} >= ${min}"
    else
        echo "[01-install-base]   ❌ ${pkg} ${current} < ${min} (USN non résolu)" >&2
        return 1
    fi
}
check_pkg_min_version libgnutls30  "3.7.3-4ubuntu1.9"
check_pkg_min_version libarchive13 "3.6.0-1ubuntu1.7"
check_pkg_min_version bind9-host   "1:9.18.39-0ubuntu0.22.04.4"
check_pkg_min_version bind9-libs   "1:9.18.39-0ubuntu0.22.04.4"
check_pkg_min_version libwbclient0 "2:4.15.13+dfsg-0ubuntu1.12"

# ---------------------------------------------------------------------------
# 2.c Paramètres kernel GRUB (T1 — Politique 200.4)
#     Requis : console=ttyS0 earlyprintk=ttyS0 rootdelay=300
# ---------------------------------------------------------------------------
echo "[01-install-base] [T1] Configuration paramètres kernel GRUB..."
GRUB_PARAMS="console=ttyS0 earlyprintk=ttyS0 rootdelay=300"
if grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub; then
    sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${GRUB_PARAMS}\"|" /etc/default/grub
else
    echo "GRUB_CMDLINE_LINUX=\"${GRUB_PARAMS}\"" >> /etc/default/grub
fi
update-grub
echo "[01-install-base] [T1] GRUB_CMDLINE_LINUX configuré :"
grep "^GRUB_CMDLINE_LINUX=" /etc/default/grub

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
