#!/usr/bin/env bash
# =============================================================================
# packer/scripts/marketplace-gallery-recreate.sh
# ADR-800 · Fix publisher image definition — correction dropdown Partner Center
# ADR-601 · Nomenclature : {objet}-{action}.sh → marketplace-gallery-recreate.sh
# ADR-602 · Logique extraite du Makefile (règle des 3 lignes)
# =============================================================================
# Recrée l'image definition Azure Compute Gallery avec GALLERY_IMAGE_PUBLISHER
# comme publisher, afin qu'elle apparaisse dans le dropdown "Gallery image"
# du Partner Center (le publisher doit correspondre au Partner Center ID).
#
# Séquence :
#   1. Sauvegarder versions existantes + leurs sources (idempotence)
#   2. Supprimer toutes les versions existantes
#   3. Supprimer l'image definition
#   4. Recréer l'image definition avec publisher=GALLERY_IMAGE_PUBLISHER
#   5a. Recréer les versions depuis les sources sauvegardées (si ≥1 version existait)
#   5b. Créer une version depuis la dernière managed image (si aucune version existante)
#
# Variables requises (via env/.env.dev ou env/.env.dev.user) :
#   GALLERY_NAME             — ex: galSMWMarketplace
#   GALLERY_RESOURCE_GROUP   — ex: rg-smw-marketplace
#   GALLERY_IMAGE_NAME       — ex: smw-knowledge-base
#   GALLERY_IMAGE_PUBLISHER  — ex: cotechnoe  (doit correspondre au Partner Center ID)
#   AZURE_SUBSCRIPTION_ID    — ex: ae487cf3-...
#   AZURE_LOCATION           — ex: canadacentral
#   SMW_VERSION              — ex: 6.0.1
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ -f "${REPO_ROOT}/env/.env.dev" ]]; then
    set -a && source "${REPO_ROOT}/env/.env.dev" && set +a
fi
if [[ -f "${REPO_ROOT}/env/.env.dev.user" ]]; then
    set -a && source "${REPO_ROOT}/env/.env.dev.user" && set +a
fi

: "${GALLERY_NAME:?Variable GALLERY_NAME requise}"
: "${GALLERY_RESOURCE_GROUP:?Variable GALLERY_RESOURCE_GROUP requise}"
: "${GALLERY_IMAGE_NAME:?Variable GALLERY_IMAGE_NAME requise}"
: "${GALLERY_IMAGE_PUBLISHER:?Variable GALLERY_IMAGE_PUBLISHER requise}"
: "${AZURE_SUBSCRIPTION_ID:?Variable AZURE_SUBSCRIPTION_ID requise}"
: "${AZURE_LOCATION:?Variable AZURE_LOCATION requise}"
: "${SMW_VERSION:?Variable SMW_VERSION requise}"

# Paramètres fixes de l'image definition SMW (Ubuntu 22.04 LTS Gen2 TrustedLaunch)
OFFER="${GALLERY_IMAGE_NAME}"
SKU="22_04-lts-gen2"
OS_TYPE="Linux"
OS_STATE="Generalized"
HYPER_V="V2"
SECURITY_TYPE="TrustedLaunch"

printf "${BLUE}=== Recréation image definition : %s ===${NC}\n" "${GALLERY_IMAGE_NAME}"
printf "${BLUE}    Gallery        : %s${NC}\n" "${GALLERY_NAME}"
printf "${BLUE}    Publisher cible : %s${NC}\n" "${GALLERY_IMAGE_PUBLISHER}"
printf "${BLUE}    Resource group  : %s${NC}\n" "${GALLERY_RESOURCE_GROUP}"
printf "\n"

# ---------------------------------------------------------------------------
# Étape 1 : Sauvegarder les versions + sources existantes
# ---------------------------------------------------------------------------
printf "${CYAN}>> Étape 1/5 — Inventaire des versions existantes...${NC}\n"

mapfile -t SAVED_VERSIONS < <(
    az sig image-version list \
        --resource-group "${GALLERY_RESOURCE_GROUP}" \
        --gallery-name "${GALLERY_NAME}" \
        --gallery-image-definition "${GALLERY_IMAGE_NAME}" \
        --query "[].name" \
        --output tsv 2>/dev/null || true)

mapfile -t SAVED_SOURCES < <(
    az sig image-version list \
        --resource-group "${GALLERY_RESOURCE_GROUP}" \
        --gallery-name "${GALLERY_NAME}" \
        --gallery-image-definition "${GALLERY_IMAGE_NAME}" \
        --query "[].storageProfile.source.id" \
        --output tsv 2>/dev/null || true)

VERSION_COUNT=${#SAVED_VERSIONS[@]}
# Filtrer le cas où mapfile renvoie un seul élément vide
if [[ "${VERSION_COUNT}" -eq 1 && -z "${SAVED_VERSIONS[0]:-}" ]]; then
    VERSION_COUNT=0
fi

if [[ "${VERSION_COUNT}" -gt 0 ]]; then
    printf "${BLUE}   %d version(s) sauvegardée(s) :%s\n" "${VERSION_COUNT}" "${NC}"
    for i in "${!SAVED_VERSIONS[@]}"; do
        printf "${BLUE}   • %s  ← %s${NC}\n" "${SAVED_VERSIONS[$i]}" "${SAVED_SOURCES[$i]:-<source inconnue>}"
    done
else
    printf "${YELLOW}   Aucune version existante (definition vide ou absente)${NC}\n"
fi

# ---------------------------------------------------------------------------
# Étape 2 : Supprimer toutes les versions existantes
# ---------------------------------------------------------------------------
printf "${CYAN}>> Étape 2/5 — Suppression des versions existantes...${NC}\n"

for v in "${SAVED_VERSIONS[@]:-}"; do
    [[ -z "$v" ]] && continue
    printf "${YELLOW}   Suppression version %s...${NC}\n" "$v"
    az sig image-version delete \
        --resource-group "${GALLERY_RESOURCE_GROUP}" \
        --gallery-name "${GALLERY_NAME}" \
        --gallery-image-definition "${GALLERY_IMAGE_NAME}" \
        --gallery-image-version "$v"
    printf "${GREEN}   ✓ Version %s supprimée${NC}\n" "$v"
done

# ---------------------------------------------------------------------------
# Étape 3 : Supprimer l'image definition
# ---------------------------------------------------------------------------
printf "${CYAN}>> Étape 3/5 — Suppression de l'image definition %s...${NC}\n" "${GALLERY_IMAGE_NAME}"

if az sig image-definition show \
        --resource-group "${GALLERY_RESOURCE_GROUP}" \
        --gallery-name "${GALLERY_NAME}" \
        --gallery-image-definition "${GALLERY_IMAGE_NAME}" \
        &>/dev/null; then
    az sig image-definition delete \
        --resource-group "${GALLERY_RESOURCE_GROUP}" \
        --gallery-name "${GALLERY_NAME}" \
        --gallery-image-definition "${GALLERY_IMAGE_NAME}"
    printf "${GREEN}   ✓ Definition supprimée${NC}\n"
else
    printf "${YELLOW}   Definition déjà absente, on continue${NC}\n"
fi

# ---------------------------------------------------------------------------
# Étape 4 : Recréer l'image definition avec le bon publisher
# ---------------------------------------------------------------------------
printf "${CYAN}>> Étape 4/5 — Création de la definition avec publisher=%s...${NC}\n" "${GALLERY_IMAGE_PUBLISHER}"

az sig image-definition create \
    --resource-group "${GALLERY_RESOURCE_GROUP}" \
    --gallery-name "${GALLERY_NAME}" \
    --gallery-image-definition "${GALLERY_IMAGE_NAME}" \
    --publisher "${GALLERY_IMAGE_PUBLISHER}" \
    --offer "${OFFER}" \
    --sku "${SKU}" \
    --os-type "${OS_TYPE}" \
    --os-state "${OS_STATE}" \
    --hyper-v-generation "${HYPER_V}" \
    --features "SecurityType=${SECURITY_TYPE}"

printf "${GREEN}   ✓ Definition créée avec publisher=%s${NC}\n" "${GALLERY_IMAGE_PUBLISHER}"

# ---------------------------------------------------------------------------
# Étape 5 : Recréer les versions d'image
# ---------------------------------------------------------------------------
printf "${CYAN}>> Étape 5/5 — Recréation des versions...${NC}\n"

if [[ "${VERSION_COUNT}" -gt 0 ]]; then
    # Recréer depuis les sources sauvegardées à l'étape 1
    for i in "${!SAVED_VERSIONS[@]}"; do
        v="${SAVED_VERSIONS[$i]}"
        src="${SAVED_SOURCES[$i]:-}"
        [[ -z "$v" ]] && continue
        printf "${YELLOW}   Recréation version %s depuis %s...${NC}\n" "$v" "$src"
        az sig image-version create \
            --resource-group "${GALLERY_RESOURCE_GROUP}" \
            --gallery-name "${GALLERY_NAME}" \
            --gallery-image-definition "${GALLERY_IMAGE_NAME}" \
            --gallery-image-version "$v" \
            --managed-image "$src" \
            --target-regions "${AZURE_LOCATION}" \
            --storage-account-type Standard_LRS
        printf "${GREEN}   ✓ Version %s recréée${NC}\n" "$v"
    done
else
    # Aucune version préexistante — dériver depuis la dernière managed image disponible
    printf "${YELLOW}   Recherche de la managed image source (préfixe : tmp-%s-%s-)...${NC}\n" \
        "${GALLERY_IMAGE_NAME}" "${SMW_VERSION}"

    MANAGED_IMAGE_PREFIX="tmp-${GALLERY_IMAGE_NAME}-${SMW_VERSION}-"
    MANAGED_IMAGE_NAME=$(az image list \
        --resource-group "${GALLERY_RESOURCE_GROUP}" \
        --query "[?starts_with(name, '${MANAGED_IMAGE_PREFIX}')].name | sort(@) | [-1]" \
        --output tsv 2>/dev/null || true)

    if [[ -z "${MANAGED_IMAGE_NAME}" ]]; then
        printf "${YELLOW}⚠ Aucune managed image avec le préfixe '%s' trouvée.${NC}\n" "${MANAGED_IMAGE_PREFIX}"
        printf "${YELLOW}  Exécutez 'make image-build' pour construire l'image,${NC}\n"
        printf "${YELLOW}  puis relancez 'make marketplace-gallery-recreate'.${NC}\n"
        printf "${GREEN}✓ Image definition recréée (sans version) — publisher=%s${NC}\n" "${GALLERY_IMAGE_PUBLISHER}"
        exit 0
    fi

    BUILD_DATE="${MANAGED_IMAGE_NAME##*-}"
    SMW_MAJOR_MINOR="${SMW_VERSION%.*}"
    GALLERY_IMAGE_VERSION="${SMW_MAJOR_MINOR}.${BUILD_DATE}"
    MANAGED_IMAGE_ID="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${GALLERY_RESOURCE_GROUP}/providers/Microsoft.Compute/images/${MANAGED_IMAGE_NAME}"

    printf "${YELLOW}   Managed image  : %s${NC}\n" "${MANAGED_IMAGE_NAME}"
    printf "${YELLOW}   Version gallery : %s${NC}\n" "${GALLERY_IMAGE_VERSION}"

    az sig image-version create \
        --resource-group "${GALLERY_RESOURCE_GROUP}" \
        --gallery-name "${GALLERY_NAME}" \
        --gallery-image-definition "${GALLERY_IMAGE_NAME}" \
        --gallery-image-version "${GALLERY_IMAGE_VERSION}" \
        --managed-image "${MANAGED_IMAGE_ID}" \
        --target-regions "${AZURE_LOCATION}" \
        --storage-account-type Standard_LRS

    printf "${GREEN}   ✓ Version %s créée depuis %s${NC}\n" "${GALLERY_IMAGE_VERSION}" "${MANAGED_IMAGE_NAME}"
fi

printf "\n"
printf "${GREEN}✓ Image definition '%s' recréée avec publisher='%s'${NC}\n" \
    "${GALLERY_IMAGE_NAME}" "${GALLERY_IMAGE_PUBLISHER}"
printf "${BLUE}ℹ Vérifiez dans Partner Center : %s / %s${NC}\n" \
    "${GALLERY_NAME}" "${GALLERY_IMAGE_NAME}"
