#!/usr/bin/env bash
# packer/provisioners/06-install-smw.sh
# Installation Semantic MediaWiki via Composer + extensions complémentaires
# ADR-613 — Architecture et Validation des Provisioners Packer
# ADR-616 — Blob Storage Azure comme Cache de Packages
#
# Variables d'environnement injectées par Packer (smw-vm.pkr.hcl) :
#   SMW_VERSION           — ex: 6.0.1
#   MEDIAWIKI_VERSION     — ex: 1.43.0
#   BLOB_STORAGE_BASE_URL — URL de base du cache blob (sans slash final)
#   SMW_LOG_FILE          — chemin du fichier de log
#
# ⚠️ Aucune version codée en dur dans ce script.
set -euo pipefail

LOG_FILE="${SMW_LOG_FILE:-/var/log/smw-install.log}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "[06-install-smw] Démarrage — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[06-install-smw] SMW_VERSION=${SMW_VERSION}"
echo "[06-install-smw] MEDIAWIKI_VERSION=${MEDIAWIKI_VERSION}"
echo "[06-install-smw] BLOB_STORAGE_BASE_URL=${BLOB_STORAGE_BASE_URL:-<non défini>}"
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

MW_DIR="/opt/mediawiki"

# ---------------------------------------------------------------------------
# 0. Préparation du répertoire de cache Composer
# ---------------------------------------------------------------------------
# www-data a besoin d'un cache Composer accessible en écriture. Si le répertoire
# n'existe pas ou n'est pas accessible, git clone (fallback dist) échoue fatalement.
install -d -m 755 -o www-data -g www-data /var/www/.cache/composer
install -d -m 755 -o www-data -g www-data /var/www/.cache/composer/repo
install -d -m 755 -o www-data -g www-data /var/www/.cache/composer/vcs
install -d -m 755 -o www-data -g www-data /var/www/.cache/composer/files

# ---------------------------------------------------------------------------
# 1. Installation de Semantic MediaWiki via Composer
# ---------------------------------------------------------------------------
echo "[06-install-smw] Installation de SMW ${SMW_VERSION} via Composer..."
cd "${MW_DIR}"

# phpunit/phpunit (require-dev de MediaWiki) a l'advisory PKSA-z3gr-8qht-p93v.
# Il n'est pas installé en production (--update-no-dev), mais Composer bloque
# quand même la résolution du graphe de dépendances. On désactive ce blocage.
sudo -u www-data composer config --no-interaction --json audit.block-insecure false

# Exécution Composer en tant que www-data pour respecter les droits
sudo -u www-data composer require \
    --no-interaction \
    --no-progress \
    --update-no-dev \
    "mediawiki/semantic-media-wiki:~${SMW_VERSION}"

# ---------------------------------------------------------------------------
# 2. Installation des extensions complémentaires SMW
# ---------------------------------------------------------------------------
echo "[06-install-smw] Installation des extensions complémentaires..."
sudo -u www-data composer require \
    --no-interaction \
    --no-progress \
    --update-no-dev \
    "mediawiki/semantic-result-formats:*" \
    "mediawiki/maps:*"

# ---------------------------------------------------------------------------
# 3. Génération d'un LocalSettings.php partiel (squelette)
#    Le LocalSettings.php complet est finalisé au premier boot via cloud-init
#    (ADR-613 — configuration différée, ADR-800)
# ---------------------------------------------------------------------------
echo "[06-install-smw] Création du LocalSettings.php partiel..."
cat > "${MW_DIR}/LocalSettings.php" <<'PHP'
<?php
# LocalSettings.php — Semantic MediaWiki Marketplace
# ⚠️ Ce fichier est un squelette généré lors du build de l'image.
#    La configuration définitive (DB, URL wiki, admin) est injectée
#    au premier démarrage de la VM via cloud-init (ADR-800).
#    NE PAS modifier directement ce fichier sans mettre à jour cloud-init.

# Inclure la configuration générée au premier boot
if ( file_exists( __DIR__ . '/LocalSettings.firstboot.php' ) ) {
    require_once __DIR__ . '/LocalSettings.firstboot.php';
}

# Skins bundlées — activation explicite requise depuis MediaWiki 1.24+
# Ref: https://www.mediawiki.org/wiki/Manual:Skin_autodiscovery
wfLoadSkin( 'Vector' );      # fournit 'vector' et 'vector-2022'
wfLoadSkin( 'MonoBook' );
wfLoadSkin( 'Timeless' );
wfLoadSkin( 'MinervaNeue' );

$wgDefaultSkin = 'vector-2022';

# Semantic MediaWiki — chargement de l'extension
wfLoadExtension( 'SemanticMediaWiki' );
enableSemantics( $wgServer ?? 'localhost' );

# Semantic Result Formats
wfLoadExtension( 'SemanticResultFormats' );

# Maps
wfLoadExtension( 'Maps' );
PHP

chown www-data:www-data "${MW_DIR}/LocalSettings.php"
chmod 640 "${MW_DIR}/LocalSettings.php"

echo "[06-install-smw] Terminé — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"
