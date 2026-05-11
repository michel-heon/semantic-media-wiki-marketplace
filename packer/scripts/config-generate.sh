#!/usr/bin/env bash
# =============================================================================
# packer/scripts/config-generate.sh
# ADR-600 : Génère env/generated/config.make et packer/generated.pkrvars.hcl
# ADR-601 : config-generate — nomenclature {objet}-{action}.sh
# ADR-602 : Logique extraite du Makefile (règle des 3 lignes)
#
# ATTENTION : env/generated/ est AUTO-GÉNÉRÉ — NE JAMAIS ÉDITER MANUELLEMENT
# Workflow : éditer env/.env.dev ou env/.env.dev.user → make config
# =============================================================================
# Usage: bash packer/scripts/config-generate.sh
# =============================================================================
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; NC='\033[0m'

ENV_DEV="${ENV_DEV:-env/.env.dev}"
ENV_USER="${ENV_USER:-env/.env.dev.user}"
CONFIG_MAKE="env/generated/config.make"
PKRVARS="packer/generated.pkrvars.hcl"

mkdir -p env/generated packer

# --- Générer env/generated/config.make ---
printf "${CYAN}>> Génération de env/generated/config.make...${NC}\n"
{
    printf "# Fichier généré automatiquement par 'make config' — NE PAS ÉDITER\n"
    printf "# Généré le: %s\n" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    [ -f "$ENV_DEV" ]  && grep -v '^#' "$ENV_DEV"  | grep '=' || true
    [ -f "$ENV_USER" ] && grep -v '^#' "$ENV_USER" | grep '=' || true
} > "$CONFIG_MAKE"

# --- Générer packer/generated.pkrvars.hcl ---
printf "${CYAN}>> Génération de packer/generated.pkrvars.hcl...${NC}\n"
{
    printf "# Fichier généré automatiquement par 'make config' — NE PAS ÉDITER\n"
    [ -f "$ENV_DEV" ]  && grep -v '^#' "$ENV_DEV"  | grep '=' | \
        sed 's/\([A-Z_]*\)=\(.*\)/\L\1\E = \2/' || true
    [ -f "$ENV_USER" ] && grep -v '^#' "$ENV_USER" | grep '=' | \
        sed 's/\([A-Z_]*\)=\(.*\)/\L\1\E = \2/' || true
} > "$PKRVARS"

printf "${GREEN}>> Configuration générée : ${CONFIG_MAKE} + ${PKRVARS}${NC}\n"
