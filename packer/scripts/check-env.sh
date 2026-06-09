#!/usr/bin/env bash
# =============================================================================
# packer/scripts/check-env.sh
# ADR-601 : check-env — Validation des variables d'environnement requises
# ADR-602 : Logique extraite du Makefile (règle des 3 lignes)
# =============================================================================
# Usage: bash packer/scripts/check-env.sh
# Retourne 0 si toutes les variables sont présentes, 1 sinon.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

ENV_DEV="${ENV_DEV:-env/.env.dev}"
ENV_USER="${ENV_USER:-env/.env.dev.user}"

set -a
[ -f "$ENV_DEV" ]  && . "$ENV_DEV"  || true
[ -f "$ENV_USER" ] && . "$ENV_USER" || true
set +a

missing=0
for var in AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET; do
    val=$(printenv "$var" 2>/dev/null || true)
    if [ -z "$val" ] || [ "$val" = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" ]; then
        printf "${RED}  MANQUANT: ${var}${NC}\n"
        missing=$((missing + 1))
    else
        printf "${GREEN}  OK: ${var}${NC}\n"
    fi
done

if [ "$missing" -gt 0 ]; then
    printf "${RED}>> ${missing} variable(s) manquante(s). Remplir env/.env.dev.user${NC}\n"
    exit 1
fi
