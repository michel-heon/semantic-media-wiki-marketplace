#!/usr/bin/env bash
# =============================================================================
# packer/scripts/azure-credential.sh
# ADR-601 : azure-credential — Login Azure et injection des credentials SP
# ADR-602 : Logique extraite du Makefile (règle des 3 lignes)
# =============================================================================
# Usage: bash packer/scripts/azure-credential.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

ENV_USER="${ENV_USER:-env/.env.dev.user}"

command -v az >/dev/null 2>&1 || {
    printf "${RED}ERREUR: az cli non installé. Voir https://learn.microsoft.com/cli/azure/install-azure-cli${NC}\n"
    exit 1
}

printf "${CYAN}>> Connexion Azure via navigateur...${NC}\n"
az login --output none

printf "${CYAN}>> Extraction de la souscription active...${NC}\n"
SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null)
TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null)

if [ -z "$SUBSCRIPTION_ID" ]; then
    printf "${RED}>> Impossible d'obtenir la souscription. Vérifiez le login Azure.${NC}\n"
    exit 1
fi

printf "${CYAN}>> Souscription : ${SUBSCRIPTION_ID}${NC}\n"
printf "${CYAN}>> Tenant       : ${TENANT_ID}${NC}\n"

SP_TMPFILE=$(mktemp /tmp/sp-smw-XXXXXX.json)
trap 'rm -f "$SP_TMPFILE"' EXIT

EXISTING_SP=$(az ad sp list --display-name "sp-smw-packer" --query "[0].appId" -o tsv 2>/dev/null || true)

if [ -n "$EXISTING_SP" ] && [ "$EXISTING_SP" != "None" ]; then
    printf "${YELLOW}>> SP 'sp-smw-packer' existant détecté — régénération des credentials...${NC}\n"
    az ad sp credential reset --id "$EXISTING_SP" --only-show-errors --output json > "$SP_TMPFILE" 2>/dev/null
else
    printf "${CYAN}>> Création du Service Principal 'sp-smw-packer'...${NC}\n"
    az ad sp create-for-rbac \
        --name "sp-smw-packer" \
        --role "Contributor" \
        --scopes "/subscriptions/${SUBSCRIPTION_ID}" \
        --only-show-errors \
        --output json > "$SP_TMPFILE" 2>/dev/null
fi

if ! grep -q '"appId"' "$SP_TMPFILE" 2>/dev/null; then
    printf "${RED}>> Erreur SP — contenu reçu :${NC}\n"
    cat "$SP_TMPFILE"
    exit 1
fi

CLIENT_ID=$(python3 -c "import json; d=json.load(open('$SP_TMPFILE')); print(d['appId'])")
CLIENT_SECRET=$(python3 -c "import json; d=json.load(open('$SP_TMPFILE')); print(d['password'])")

printf "${GREEN}  CLIENT_ID     : ${CLIENT_ID}${NC}\n"

awk -v sid="$SUBSCRIPTION_ID" -v ten="$TENANT_ID" \
    -v cli="$CLIENT_ID" -v sec="$CLIENT_SECRET" \
    '/^AZURE_SUBSCRIPTION_ID=/ { print "AZURE_SUBSCRIPTION_ID=\"" sid "\""; next }
     /^AZURE_TENANT_ID=/        { print "AZURE_TENANT_ID=\"" ten "\""; next }
     /^AZURE_CLIENT_ID=/        { print "AZURE_CLIENT_ID=\"" cli "\""; next }
     /^AZURE_CLIENT_SECRET=/    { print "AZURE_CLIENT_SECRET=\"" sec "\""; next }
     { print }' env/.env.dev.user.example > "$ENV_USER"

printf "${GREEN}>> Credentials injectés dans ${ENV_USER}${NC}\n"
