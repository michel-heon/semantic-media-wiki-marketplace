#!/usr/bin/env bash
# packer/scripts/storage-provision.sh
# Gestion du cache Blob Storage Azure pour les packages de build Packer
# ADR-616 — Blob Storage Azure comme Cache de Packages
#
# Usage:
#   ./storage-provision.sh create   — créer le compte de stockage et le conteneur
#   ./storage-provision.sh upload   — uploader les packages dans le blob
#   ./storage-provision.sh verify   — vérifier la présence des packages
#   ./storage-provision.sh list     — lister les blobs présents
#   ./storage-provision.sh urls     — afficher les URLs des blobs
#
# Variables d'environnement requises (env/.env.dev + env/.env.dev.user) :
#   AZURE_SUBSCRIPTION_ID   — ID de souscription Azure
#   AZURE_RESOURCE_GROUP    — Groupe de ressources (rg-smw-marketplace)
#   AZURE_LOCATION          — Région Azure (canadacentral)
#   STORAGE_ACCOUNT         — Nom du compte de stockage (stsmwmarketplace)
#   BLOB_STORAGE_BASE_URL   — URL de base du conteneur (sans slash final)
#   SMW_VERSION             — Version SMW ex: 6.0.1
#   MEDIAWIKI_VERSION       — Version MediaWiki ex: 1.43.0
#   PHP_VERSION             — Version PHP ex: 8.2 (pour composer.phar)
set -euo pipefail

# ---------------------------------------------------------------------------
# Couleurs (cohérence avec ADR-611)
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Chargement des fichiers .env si disponibles
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ -f "${REPO_ROOT}/env/.env.dev" ]]; then
    # shellcheck disable=SC1091
    set -a && source "${REPO_ROOT}/env/.env.dev" && set +a
fi
if [[ -f "${REPO_ROOT}/env/.env.dev.user" ]]; then
    # shellcheck disable=SC1091
    set -a && source "${REPO_ROOT}/env/.env.dev.user" && set +a
fi

# ---------------------------------------------------------------------------
# Validation des variables requises
# ---------------------------------------------------------------------------
: "${AZURE_SUBSCRIPTION_ID:?Variable AZURE_SUBSCRIPTION_ID requise}"
: "${AZURE_RESOURCE_GROUP:?Variable AZURE_RESOURCE_GROUP requise}"
: "${AZURE_LOCATION:?Variable AZURE_LOCATION requise}"
: "${STORAGE_ACCOUNT:?Variable STORAGE_ACCOUNT requise}"
: "${BLOB_STORAGE_BASE_URL:?Variable BLOB_STORAGE_BASE_URL requise}"
: "${SMW_VERSION:?Variable SMW_VERSION requise}"
: "${MEDIAWIKI_VERSION:?Variable MEDIAWIKI_VERSION requise}"

CONTAINER_NAME="devops"
TMP_DIR="/tmp/smw-storage-provision"

# ---------------------------------------------------------------------------
# Liste des packages à gérer dans le blob (ADR-616)
# ---------------------------------------------------------------------------
declare -A PACKAGES
PACKAGES["mediawiki-${MEDIAWIKI_VERSION}.tar.gz"]="https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_VERSION%.*}/mediawiki-${MEDIAWIKI_VERSION}.tar.gz"
PACKAGES["smw-${SMW_VERSION}.tar.gz"]="https://github.com/SemanticMediaWiki/SemanticMediaWiki/archive/refs/tags/${SMW_VERSION}.tar.gz"
PACKAGES["composer.phar"]="https://getcomposer.org/download/latest-stable/composer.phar"

# ---------------------------------------------------------------------------
# Fonctions
# ---------------------------------------------------------------------------

cmd_create() {
    printf "${CYAN}>> Création du compte de stockage '%s' dans '%s'...${NC}\n" \
        "${STORAGE_ACCOUNT}" "${AZURE_RESOURCE_GROUP}"

    # Créer le compte de stockage si inexistant
    if ! az storage account show \
            --name "${STORAGE_ACCOUNT}" \
            --resource-group "${AZURE_RESOURCE_GROUP}" \
            --subscription "${AZURE_SUBSCRIPTION_ID}" \
            --output none 2>/dev/null; then

        az storage account create \
            --name "${STORAGE_ACCOUNT}" \
            --resource-group "${AZURE_RESOURCE_GROUP}" \
            --location "${AZURE_LOCATION}" \
            --sku Standard_LRS \
            --kind StorageV2 \
            --https-only true \
            --min-tls-version TLS1_2 \
            --subscription "${AZURE_SUBSCRIPTION_ID}"
        printf "${GREEN}  Compte de stockage créé${NC}\n"
    else
        printf "${YELLOW}  Compte de stockage déjà existant${NC}\n"
    fi

    # Créer le conteneur 'devops' avec accès public blob (ADR-616)
    if ! az storage container show \
            --name "${CONTAINER_NAME}" \
            --account-name "${STORAGE_ACCOUNT}" \
            --auth-mode login \
            --subscription "${AZURE_SUBSCRIPTION_ID}" \
            --output none 2>/dev/null; then

        az storage container create \
            --name "${CONTAINER_NAME}" \
            --account-name "${STORAGE_ACCOUNT}" \
            --public-access blob \
            --auth-mode login \
            --subscription "${AZURE_SUBSCRIPTION_ID}"
        printf "${GREEN}  Conteneur '%s' créé (accès public blob)${NC}\n" "${CONTAINER_NAME}"
    else
        printf "${YELLOW}  Conteneur '%s' déjà existant${NC}\n" "${CONTAINER_NAME}"
    fi

    printf "${GREEN}>> Blob Storage prêt${NC}\n"
}

cmd_upload() {
    printf "${CYAN}>> Upload des packages vers le blob...${NC}\n"
    mkdir -p "${TMP_DIR}"

    for package_name in "${!PACKAGES[@]}"; do
        source_url="${PACKAGES[${package_name}]}"
        local_file="${TMP_DIR}/${package_name}"
        blob_url="${BLOB_STORAGE_BASE_URL}/${package_name}"

        # Vérifier si le blob existe déjà
        if wget --spider --quiet "${blob_url}" 2>/dev/null; then
            printf "${YELLOW}  Déjà présent (skip): %s${NC}\n" "${package_name}"
            continue
        fi

        printf "${CYAN}  Téléchargement: %s${NC}\n" "${package_name}"
        wget -q "${source_url}" -O "${local_file}"

        printf "${CYAN}  Upload vers blob: %s${NC}\n" "${package_name}"
        az storage blob upload \
            --account-name "${STORAGE_ACCOUNT}" \
            --container-name "${CONTAINER_NAME}" \
            --name "${package_name}" \
            --file "${local_file}" \
            --auth-mode login \
            --subscription "${AZURE_SUBSCRIPTION_ID}" \
            --overwrite

        rm -f "${local_file}"
        printf "${GREEN}  Uploadé: %s${NC}\n" "${package_name}"
    done

    rm -rf "${TMP_DIR}"
    printf "${GREEN}>> Upload terminé${NC}\n"
}

cmd_verify() {
    printf "${CYAN}>> Vérification des packages dans le blob...${NC}\n"
    local failed=0

    for package_name in "${!PACKAGES[@]}"; do
        blob_url="${BLOB_STORAGE_BASE_URL}/${package_name}"
        if wget --spider --quiet "${blob_url}" 2>/dev/null; then
            printf "${GREEN}  OK: %s${NC}\n" "${package_name}"
        else
            printf "${RED}  MANQUANT: %s${NC}\n" "${package_name}"
            failed=$(( failed + 1 ))
        fi
    done

    if [[ "${failed}" -gt 0 ]]; then
        printf "${RED}>> %d package(s) manquant(s). Exécuter: make storage-upload${NC}\n" "${failed}"
        exit 1
    fi
    printf "${GREEN}>> Tous les packages sont présents dans le blob${NC}\n"
}

cmd_list() {
    printf "${CYAN}>> Liste des blobs dans '%s/%s':${NC}\n" "${STORAGE_ACCOUNT}" "${CONTAINER_NAME}"
    az storage blob list \
        --account-name "${STORAGE_ACCOUNT}" \
        --container-name "${CONTAINER_NAME}" \
        --auth-mode login \
        --subscription "${AZURE_SUBSCRIPTION_ID}" \
        --query "[].{name:name, size:properties.contentLength, modified:properties.lastModified}" \
        --output table
}

cmd_urls() {
    printf "${CYAN}>> URLs des packages dans le blob:${NC}\n"
    for package_name in "${!PACKAGES[@]}"; do
        printf "  ${GREEN}%s${NC}\n    %s/%s\n" \
            "${package_name}" "${BLOB_STORAGE_BASE_URL}" "${package_name}"
    done
}

usage() {
    printf "${YELLOW}Usage: %s {create|upload|verify|list|urls}${NC}\n" "$(basename "$0")"
    exit 1
}

# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------
COMMAND="${1:-}"
case "${COMMAND}" in
    create)  cmd_create ;;
    upload)  cmd_upload ;;
    verify)  cmd_verify ;;
    list)    cmd_list   ;;
    urls)    cmd_urls   ;;
    *)       usage      ;;
esac
