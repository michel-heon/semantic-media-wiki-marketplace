#!/usr/bin/env bash
# packer/provisioners/05-install-mediawiki.sh
# Installation MediaWiki 1.43.x dans /opt/mediawiki
# ADR-613 — Architecture et Validation des Provisioners Packer
# ADR-616 — Blob Storage Azure comme Cache de Packages
#
# Variables d'environnement injectées par Packer (smw-vm.pkr.hcl) :
#   MEDIAWIKI_VERSION     — ex: 1.43.0
#   BLOB_STORAGE_BASE_URL — URL de base du cache blob (sans slash final)
#   SMW_LOG_FILE          — chemin du fichier de log
#
# ⚠️ Aucune version codée en dur dans ce script.
set -euo pipefail

LOG_FILE="${SMW_LOG_FILE:-/var/log/smw-install.log}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "[05-install-mediawiki] Démarrage — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[05-install-mediawiki] MEDIAWIKI_VERSION=${MEDIAWIKI_VERSION}"
echo "[05-install-mediawiki] BLOB_STORAGE_BASE_URL=${BLOB_STORAGE_BASE_URL:-<non défini>}"
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

# ---------------------------------------------------------------------------
# 1. Dérivation du numéro de version majeur.mineur pour l'URL d'archive
# ---------------------------------------------------------------------------
# Ex: 1.43.0 → 1.43
MW_MAJOR_MINOR="${MEDIAWIKI_VERSION%.*}"
ARCHIVE_NAME="mediawiki-${MEDIAWIKI_VERSION}.tar.gz"
ARCHIVE_SOURCE="https://releases.wikimedia.org/mediawiki/${MW_MAJOR_MINOR}/${ARCHIVE_NAME}"
ARCHIVE_TMP="/tmp/${ARCHIVE_NAME}"

# ---------------------------------------------------------------------------
# 2. Téléchargement de l'archive MediaWiki
# ---------------------------------------------------------------------------
echo "[05-install-mediawiki] Téléchargement de MediaWiki ${MEDIAWIKI_VERSION}..."
download_package "${ARCHIVE_NAME}" "${ARCHIVE_SOURCE}" "${ARCHIVE_TMP}"

# ---------------------------------------------------------------------------
# 3. Extraction dans /opt/mediawiki (ownership www-data, ADR-613)
# ---------------------------------------------------------------------------
echo "[05-install-mediawiki] Extraction de l'archive..."
TMP_EXTRACT="/tmp/mediawiki-extract"
mkdir -p "${TMP_EXTRACT}"
tar -xzf "${ARCHIVE_TMP}" -C "${TMP_EXTRACT}" --strip-components=1

# Synchroniser dans /opt/mediawiki
rsync -a "${TMP_EXTRACT}/" /opt/mediawiki/

# Nettoyage
rm -rf "${TMP_EXTRACT}" "${ARCHIVE_TMP}"

# ---------------------------------------------------------------------------
# 4. Droits ownership
# ---------------------------------------------------------------------------
echo "[05-install-mediawiki] Configuration des droits..."
chown -R www-data:www-data /opt/mediawiki
# Répertoires traversables (755) — obligatoire pour que azureuser puisse vérifier
# l'image sans être www-data ; fichiers protégés (640, lisibles seulement par
# www-data et le groupe). ADR-613 : ownership www-data:www-data maintenu.
find /opt/mediawiki -type d -exec chmod 755 {} +
find /opt/mediawiki -type f -exec chmod 640 {} +

# Répertoire uploads sur /data/uploads (ADR-613)
mkdir -p /data/uploads
chown -R www-data:www-data /data/uploads
chmod 755 /data/uploads

# Lien symbolique pour les images/uploads MediaWiki
if [[ -d /opt/mediawiki/images ]]; then
    rm -rf /opt/mediawiki/images
fi
ln -sf /data/uploads /opt/mediawiki/images

# ---------------------------------------------------------------------------
# 5. Configuration Apache — lien symbolique si besoin
# ---------------------------------------------------------------------------
# Le VirtualHost Apache pointe déjà sur /opt/mediawiki (voir 03-install-apache.sh)
echo "[05-install-mediawiki] Vérification du DocumentRoot Apache..."
if [[ ! -f /opt/mediawiki/index.php ]]; then
    echo "[05-install-mediawiki] AVERTISSEMENT: index.php non trouvé dans /opt/mediawiki"
fi

echo "[05-install-mediawiki] Terminé — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"
