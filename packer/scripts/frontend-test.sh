#!/usr/bin/env bash
# =============================================================================
# packer/scripts/frontend-test.sh
# ADR-601 : frontend-test — Tests UI frontend de la VM SMW de test
# ADR-602 : Logique extraite du Makefile (règle des 3 lignes)
#
# Sous-commandes :
#   login-ui   Tester la page de login MediaWiki (HTTP check + validation contenu)
# =============================================================================
# Usage: bash packer/scripts/frontend-test.sh <login-ui>
# Variables d'environnement optionnelles :
#   E2E_RG    Resource group E2E (défaut : rg-smw-marketplace-e2e)
#   BASE_URL  URL de base de la VM (auto-détectée si absent)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# --- Source de la configuration générée (ADR-600) ---
CONFIG_MAKE="env/generated/config.make"
if [ -f "$CONFIG_MAKE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_MAKE"
else
    printf "${RED}✗ ${CONFIG_MAKE} absent — lancez : make config${NC}\n"
    exit 1
fi

E2E_RG="${E2E_RG:-rg-smw-marketplace-e2e}"

# --- Helpers ---
find_test_vm_ip() {
    local VM
    VM=$(az vm list -g "$E2E_RG" \
        --query "[?starts_with(name,'test-smw')].name | sort(@) | [-1]" \
        -o tsv 2>/dev/null || true)
    if [ -z "$VM" ]; then
        printf "" ; return
    fi
    az vm list-ip-addresses -g "$E2E_RG" -n "$VM" \
        --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
        -o tsv 2>/dev/null || true
}

# --- Dispatch des sous-commandes ---
cmd="${1:-}"

case "$cmd" in
    login-ui)
        if [ -z "${BASE_URL:-}" ]; then
            IP=$(find_test_vm_ip)
            if [ -z "$IP" ]; then
                printf "${RED}  ✗ Aucune VM de test trouvée dans ${E2E_RG}${NC}\n"
                printf "${YELLOW}  Créez d'abord une VM avec : make vm-ensure${NC}\n"
                exit 1
            fi
            BASE_URL="http://${IP}"
        fi

        LOGIN_URL="${BASE_URL}/index.php?title=Special:UserLogin"
        printf "${CYAN}  → Test login UI MediaWiki : ${LOGIN_URL}${NC}\n"

        HTTP_STATUS=$(curl -s -o /tmp/smw-login-test.html -w "%{http_code}" \
            --max-time 15 \
            --connect-timeout 10 \
            -L -k \
            "${LOGIN_URL}" || echo "000")

        if [ "$HTTP_STATUS" = "200" ]; then
            # Vérifier la présence du formulaire de login dans la réponse
            if grep -qi "wpLoginToken\|userloginForm\|wpName\|wpPassword" /tmp/smw-login-test.html 2>/dev/null; then
                printf "${GREEN}  ✓ Page de login accessible et formulaire présent (HTTP ${HTTP_STATUS})${NC}\n"
            else
                printf "${YELLOW}  ⚠ Page accessible (HTTP ${HTTP_STATUS}) mais formulaire login non détecté${NC}\n"
            fi
        else
            printf "${RED}  ✗ Page de login inaccessible (HTTP ${HTTP_STATUS})${NC}\n"
            printf "${YELLOW}  URL testée : ${LOGIN_URL}${NC}\n"
            exit 1
        fi
        rm -f /tmp/smw-login-test.html
        ;;

    *)
        printf "${RED}Usage: $0 <login-ui>${NC}\n"
        exit 1
        ;;
esac
