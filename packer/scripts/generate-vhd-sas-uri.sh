#!/usr/bin/env bash
# =============================================================================
# generate-vhd-sas-uri.sh - Génération SAS URI pour soumission Partner Center (T11)
# ADR-800 §Décision 8 · Issue #4 (T11)
#
# ⚠️ Méthode LEGACY. Préférer Azure Compute Gallery (cf. docs/Partner/sas-uri-procedure.md §2).
# À n'utiliser qu'en fallback explicite demandé par Partner Center.
#
# Usage:
#   bash packer/scripts/generate-vhd-sas-uri.sh
#   # ou avec surcharges:
#   STORAGE_ACCOUNT=stsmwmarketplace VHD_NAME=smw-vm.vhd EXPIRY_DAYS=30 \
#       bash packer/scripts/generate-vhd-sas-uri.sh
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Couleurs (ADR-611)
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

# ---------------------------------------------------------------------------
# Chargement environnement
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
for f in "${REPO_ROOT}/env/.env.dev" "${REPO_ROOT}/env/.env.dev.user"; do
    [[ -f "$f" ]] && { set -a; source "$f"; set +a; }
done

# ---------------------------------------------------------------------------
# Variables (avec valeurs par défaut)
# ---------------------------------------------------------------------------
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-stsmwmarketplace}"
RESOURCE_GROUP="${MARKETPLACE_RESOURCE_GROUP:-rg-smw-marketplace}"
CONTAINER="${CONTAINER:-vhds}"
VHD_NAME="${VHD_NAME:-smw-vm.vhd}"
EXPIRY_DAYS="${EXPIRY_DAYS:-30}"

# Validation
if [[ "$EXPIRY_DAYS" -lt 21 ]]; then
    printf "${RED}✗ EXPIRY_DAYS=$EXPIRY_DAYS — minimum 21 jours (3 semaines) requis par Microsoft${NC}\n"
    exit 1
fi

EXPIRY=$(date -u -d "+${EXPIRY_DAYS} days" '+%Y-%m-%dT%H:%MZ')

printf "\n${BOLD}${CYAN}Génération SAS URI pour Partner Center${NC}\n"
printf "${CYAN}════════════════════════════════════════${NC}\n"
printf "  Storage account : ${BOLD}%s${NC}\n" "$STORAGE_ACCOUNT"
printf "  Resource group  : ${BOLD}%s${NC}\n" "$RESOURCE_GROUP"
printf "  Container       : ${BOLD}%s${NC}\n" "$CONTAINER"
printf "  Blob            : ${BOLD}%s${NC}\n" "$VHD_NAME"
printf "  Expiry          : ${BOLD}%s${NC} (${EXPIRY_DAYS} jours)\n" "$EXPIRY"
printf "\n"

# ---------------------------------------------------------------------------
# 1. Vérifier que le blob existe
# ---------------------------------------------------------------------------
printf "${CYAN}[1/3]${NC} Vérification existence du blob...\n"
if ! az storage blob exists \
        --account-name "$STORAGE_ACCOUNT" \
        --container-name "$CONTAINER" \
        --name "$VHD_NAME" \
        --auth-mode login \
        --query exists -o tsv 2>/dev/null | grep -q true; then
    printf "  ${RED}✗ Blob introuvable :${NC} %s/%s\n" "$CONTAINER" "$VHD_NAME"
    printf "  ${YELLOW}Vérifier que :${NC}\n"
    printf "    - le storage account '$STORAGE_ACCOUNT' existe\n"
    printf "    - le container '$CONTAINER' contient bien '$VHD_NAME'\n"
    printf "    - vous êtes authentifié : ${BOLD}az login${NC}\n"
    exit 1
fi
printf "  ${GREEN}✓${NC} Blob trouvé\n"

# ---------------------------------------------------------------------------
# 2. Génération du SAS URI (read+list, HTTPS only, durée validée)
# ---------------------------------------------------------------------------
printf "${CYAN}[2/3]${NC} Génération SAS token...\n"
SAS_URI=$(az storage blob generate-sas \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$CONTAINER" \
    --name "$VHD_NAME" \
    --permissions rl \
    --expiry "$EXPIRY" \
    --https-only \
    --auth-mode login \
    --as-user \
    --full-uri \
    -o tsv 2>/dev/null) || {
        printf "  ${RED}✗ Échec génération SAS${NC} — vérifier permissions:\n"
        printf "    az role assignment list --assignee \$(az ad signed-in-user show --query id -o tsv) \\\n"
        printf "        --scope /subscriptions/<sub>/resourceGroups/$RESOURCE_GROUP/.../$STORAGE_ACCOUNT\n"
        exit 1
    }
printf "  ${GREEN}✓${NC} SAS URI généré\n"

# ---------------------------------------------------------------------------
# 3. Validation paramètres requis
# ---------------------------------------------------------------------------
printf "${CYAN}[3/3]${NC} Validation paramètres requis Microsoft...\n"

check_param() {
    local name="$1" pattern="$2"
    if echo "$SAS_URI" | grep -qE "$pattern"; then
        printf "  ${GREEN}✓${NC} %s\n" "$name"
        return 0
    else
        printf "  ${RED}✗${NC} %s manquant\n" "$name"
        return 1
    fi
}

errors=0
check_param "Permissions read+list (sp=rl)"    "sp=rl"     || ((errors++))
check_param "HTTPS-only (spr=https)"           "spr=https" || ((errors++))
check_param "Expiry présent (se=...)"          "se=[0-9]"  || ((errors++))
check_param "Signature présente (sig=...)"     "sig="      || ((errors++))

if [[ $errors -gt 0 ]]; then
    printf "\n${RED}✗ SAS URI invalide — $errors paramètre(s) manquant(s)${NC}\n"
    exit 1
fi

# ---------------------------------------------------------------------------
# Test HTTP HEAD (optionnel mais recommandé)
# ---------------------------------------------------------------------------
printf "\n${CYAN}Test accès HTTP HEAD...${NC}\n"
http_code=$(curl -s -o /dev/null -w '%{http_code}' -I "$SAS_URI" 2>/dev/null || echo "000")
if [[ "$http_code" == "200" ]]; then
    printf "  ${GREEN}✓${NC} HTTP $http_code — accès lecture OK\n"
else
    printf "  ${YELLOW}⚠${NC} HTTP $http_code — vérifier manuellement\n"
fi

# ---------------------------------------------------------------------------
# Sortie sécurisée — Le SAS URI complet va à stdout SEUL
# ---------------------------------------------------------------------------
printf "\n${BOLD}${GREEN}✓ SAS URI prêt pour Partner Center${NC}\n"
printf "${CYAN}════════════════════════════════════════${NC}\n"
printf "${YELLOW}⚠ SECRET — Ne pas committer, ne pas logger en clair.${NC}\n"
printf "${YELLOW}⚠ Coller directement dans Partner Center → Technical configuration → OS VHD link.${NC}\n"
printf "\n"

# Préfixe sans signature pour audit
SAFE_PREFIX=$(echo "$SAS_URI" | sed -E 's/&sig=[^&]+/\&sig=<REDACTED>/')
printf "${CYAN}Audit trail (sig masquée):${NC}\n"
printf "  %s\n\n" "$SAFE_PREFIX"

# SAS URI complet — à copier-coller
printf "${BOLD}SAS URI complet (1 ligne — copier dans Partner Center) :${NC}\n"
printf "%s\n" "$SAS_URI"
