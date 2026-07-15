#!/usr/bin/env bash
# =============================================================================
# packer/scripts/pre-submit-smoke.sh
# ADR-601 : pre-submit-smoke — Smoke test pré-soumission Marketplace
# ADR-602 : Script orchestration (Makefile en 3 lignes)
# ADR-700 : Réutilise les suites de tests E2E + user-smoke existantes
# =============================================================================
# Usage:
#   E2E_RG=<rg> bash packer/scripts/pre-submit-smoke.sh
#   E2E_RG=<rg> VM_IP=<ip|fqdn> bash packer/scripts/pre-submit-smoke.sh
#
# Objectif:
#   Exécuter un smoke test fonctionnel complet avant soumission Partner Center :
#   - disponibilité navigateur (tests/e2e)
#   - fonctionnalités SMW utilisateur (tests/user-smoke)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

E2E_RG="${E2E_RG:-rg-smw-marketplace-e2e}"
VM_MANAGE="${REPO_ROOT}/packer/scripts/vm-manage.sh"

log_action() { printf "${CYAN}➤ %s${NC}\n" "$1"; }
log_success() { printf "${GREEN}✓ %s${NC}\n" "$1"; }
log_warn() { printf "${YELLOW}⚠ %s${NC}\n" "$1"; }
log_error() { printf "${RED}✗ %s${NC}\n" "$1"; }

log_action "Pré-check pré-soumission : validation environnement Azure"
bash "${REPO_ROOT}/packer/scripts/check-env.sh"

log_action "Pré-check infrastructure : VM présente + règles NSG 80/443 appliquées"
E2E_RG="${E2E_RG}" bash "${VM_MANAGE}" ensure >/dev/null

if [[ -z "${VM_IP:-}" ]]; then
    log_action "Résolution automatique de VM_IP depuis vm-manage.sh (E2E_RG=${E2E_RG})"
    VM_IP="$(E2E_RG="${E2E_RG}" bash "${VM_MANAGE}" get-ip 2>/dev/null || true)"
fi

if [[ -z "${VM_IP}" ]]; then
    log_error "Impossible de déterminer VM_IP (aucune VM détectée dans ${E2E_RG})"
    log_warn "Créer la VM de test puis relancer :"
    printf "  make vm-ensure E2E_RG=%s\n" "${E2E_RG}"
    exit 1
fi

log_success "Cible smoke test : ${VM_IP}"

log_action "Attente disponibilité HTTPS (max 120s)"
for _ in {1..24}; do
    if curl -k -I --max-time 5 "https://${VM_IP}/" >/dev/null 2>&1; then
        log_success "HTTPS disponible sur ${VM_IP}"
        break
    fi
    sleep 5
done
if ! curl -k -I --max-time 5 "https://${VM_IP}/" >/dev/null 2>&1; then
    log_error "HTTPS indisponible sur ${VM_IP} après 120s"
    exit 1
fi

log_action "Smoke 1/2 : tests navigateur essentiels (tests/e2e)"
make -C "${REPO_ROOT}/tests/e2e" firefox VM_IP="${VM_IP}" E2E_RG="${E2E_RG}" --no-print-directory

log_action "Pré-check user-smoke : reset WikiAdmin vers mot de passe de référence"
E2E_RG="${E2E_RG}" bash "${VM_MANAGE}" reset-admin-password >/dev/null

log_action "Smoke 2/2 : parcours fonctionnels SMW (tests/user-smoke)"
SMW_ADMIN_USER="WikiAdmin" \
SMW_ADMIN_PASSWORD="ChangeMe123!" \
VM_IP="${VM_IP}" \
"${REPO_ROOT}/tests/node_modules/.bin/playwright" test \
    --config "${REPO_ROOT}/tests/user-smoke/playwright.config.js" \
    --project firefox

log_success "Smoke test pré-soumission réussi (E2E + user-smoke)"
printf "${CYAN}Résumé:${NC} VM_IP=%s | Suites=tests/e2e + tests/user-smoke\n" "${VM_IP}"
