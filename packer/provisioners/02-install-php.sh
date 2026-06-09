#!/usr/bin/env bash
# packer/provisioners/02-install-php.sh
# Installation PHP-FPM + extensions MediaWiki/SMW (PPA ondrej/php)
# ADR-613 — Architecture et Validation des Provisioners Packer
# ADR-616 — Blob Storage Azure comme Cache de Packages
#
# Variables d'environnement injectées par Packer (smw-vm.pkr.hcl) :
#   PHP_VERSION           — ex: 8.2
#   BLOB_STORAGE_BASE_URL — URL de base du cache blob (sans slash final)
#   SMW_LOG_FILE          — chemin du fichier de log
#
# ⚠️ Aucune version codée en dur dans ce script.
set -euo pipefail

LOG_FILE="${SMW_LOG_FILE:-/var/log/smw-install.log}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "[02-install-php] Démarrage — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[02-install-php] PHP_VERSION=${PHP_VERSION}"
echo "[02-install-php] BLOB_STORAGE_BASE_URL=${BLOB_STORAGE_BASE_URL:-<non défini>}"
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
# 1. Ajout du PPA ondrej/php (PHP 8.2 non fourni par Ubuntu 22.04 en standard)
# ---------------------------------------------------------------------------
echo "[02-install-php] Ajout du PPA ondrej/php..."
add-apt-repository -y ppa:ondrej/php
apt-get update -y

# ---------------------------------------------------------------------------
# 2. Installation PHP-FPM et extensions requises par MediaWiki/SMW
#    (ADR-001 : Ubuntu 22.04 + PHP 8.2 + extensions listées)
# ---------------------------------------------------------------------------
echo "[02-install-php] Installation de PHP ${PHP_VERSION}-fpm et extensions..."
apt-get install -y \
    "php${PHP_VERSION}-fpm" \
    "php${PHP_VERSION}-mysql" \
    "php${PHP_VERSION}-xml" \
    "php${PHP_VERSION}-mbstring" \
    "php${PHP_VERSION}-intl" \
    "php${PHP_VERSION}-curl" \
    "php${PHP_VERSION}-zip" \
    "php${PHP_VERSION}-gd" \
    "php${PHP_VERSION}-cli" \
    "php${PHP_VERSION}-common" \
    "php${PHP_VERSION}-opcache" \
    "php${PHP_VERSION}-apcu"

# ---------------------------------------------------------------------------
# 3. Installation de Composer (gestionnaire de dépendances PHP)
#    Utilise le cache blob si disponible, sinon télécharge depuis getcomposer.org
# ---------------------------------------------------------------------------
COMPOSER_PACKAGE="composer.phar"
COMPOSER_SOURCE="https://getcomposer.org/download/latest-stable/composer.phar"
TMP_COMPOSER="/tmp/${COMPOSER_PACKAGE}"

echo "[02-install-php] Installation de Composer..."
download_package "${COMPOSER_PACKAGE}" "${COMPOSER_SOURCE}" "${TMP_COMPOSER}"

mv "${TMP_COMPOSER}" /usr/local/bin/composer
chmod +x /usr/local/bin/composer
composer --version

# ---------------------------------------------------------------------------
# 4. Activation du service PHP-FPM
# ---------------------------------------------------------------------------
echo "[02-install-php] Activation du service php${PHP_VERSION}-fpm..."
systemctl enable "php${PHP_VERSION}-fpm"

echo "[02-install-php] Terminé — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"
