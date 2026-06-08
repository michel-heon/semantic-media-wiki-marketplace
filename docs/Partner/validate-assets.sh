#!/usr/bin/env bash
# =============================================================================
# validate-assets.sh - Validation conformité assets Partner Center (T10)
# ADR-802 (sources) · ADR-804 (politiques 100.3.x) · Issue #4 (T10)
#
# Usage: bash docs/Partner/validate-assets.sh
# Exit 0 si tous critères PASS, exit 1 si un critère FAIL.
#
# Dépendance : ImageMagick (`identify`). Installer via: sudo apt-get install imagemagick
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ASSETS_DIR="${REPO_ROOT}/docs/Partner"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0

check() {
    local label="$1" status="$2" detail="${3:-}"
    case "$status" in
        PASS) printf "  ${GREEN}✓ PASS${NC} %-50s %s\n" "$label" "$detail"; ((++PASS)) || true ;;
        FAIL) printf "  ${RED}✗ FAIL${NC} %-50s %s\n" "$label" "$detail"; ((++FAIL)) || true ;;
        WARN) printf "  ${YELLOW}⚠ WARN${NC} %-50s %s\n" "$label" "$detail"; ((++WARN)) || true ;;
    esac
}

# Vérifier dépendance
if ! command -v identify >/dev/null 2>&1; then
    printf "${RED}✗ identify (ImageMagick) absent. Installer: sudo apt-get install imagemagick${NC}\n"
    exit 2
fi

# Récupère dimensions "WxH"
dims() {
    identify -format "%wx%h" "$1" 2>/dev/null || echo "0x0"
}

# Taille en bytes
size_b() {
    stat -c %s "$1" 2>/dev/null || echo "0"
}

printf "\n${BOLD}${CYAN}Partner Center assets — validation 100.3.x${NC}\n"
printf "${CYAN}Source: docs/Partner/${NC}\n\n"

# ----- LOGOS -----
printf "${BOLD}Logos:${NC}\n"

# Large logo (216×216 à 350×350)
LARGE="$ASSETS_DIR/cotechnoe-smw-logo-216.png"
if [[ -f "$LARGE" ]]; then
    d=$(dims "$LARGE")
    if [[ "$d" == "216x216" ]]; then
        check "Large logo cotechnoe-smw-logo-216.png" PASS "$d"
    else
        check "Large logo cotechnoe-smw-logo-216.png" FAIL "attendu 216x216, trouvé $d"
    fi
else
    check "Large logo cotechnoe-smw-logo-216.png" FAIL "fichier absent"
fi

# Large logo alternatif (350×350)
ALT="$ASSETS_DIR/SMW-logo.png"
if [[ -f "$ALT" ]]; then
    d=$(dims "$ALT")
    w=${d%x*}; h=${d#*x}
    if [[ "$w" -ge 216 && "$w" -le 350 && "$h" -ge 216 && "$h" -le 350 && "$w" == "$h" ]]; then
        check "Large logo alt SMW-logo.png (216–350 carré)" PASS "$d"
    else
        check "Large logo alt SMW-logo.png (216–350 carré)" WARN "trouvé $d"
    fi
fi

# Small logo (48×48, généré par PC mais on le fournit)
SMALL="$ASSETS_DIR/cotechnoe-smw-logo-48.png"
if [[ -f "$SMALL" ]]; then
    d=$(dims "$SMALL")
    if [[ "$d" == "48x48" ]]; then
        check "Small logo cotechnoe-smw-logo-48.png" PASS "$d"
    else
        check "Small logo cotechnoe-smw-logo-48.png" FAIL "attendu 48x48, trouvé $d"
    fi
fi

# ----- SCREENSHOTS -----
printf "\n${BOLD}Screenshots (1280×720):${NC}\n"

SCREENSHOT_COUNT=0
SCREENSHOT_FILES=()
for f in "$ASSETS_DIR"/0[1-5]-*.png; do
    [[ -f "$f" ]] || continue
    SCREENSHOT_FILES+=("$f")
    name=$(basename "$f")
    d=$(dims "$f")
    sz=$(size_b "$f")
    sz_kb=$((sz / 1024))
    if [[ "$d" == "1280x720" ]]; then
        if [[ "$sz" -lt 1048576 ]]; then
            check "$name" PASS "$d, ${sz_kb}KB"
        else
            check "$name" WARN "$d, ${sz_kb}KB (>1MB)"
        fi
        ((++SCREENSHOT_COUNT)) || true
    else
        check "$name" FAIL "attendu 1280x720, trouvé $d"
    fi
done

# Nombre max screenshots
if [[ $SCREENSHOT_COUNT -ge 1 && $SCREENSHOT_COUNT -le 5 ]]; then
    check "100.3.3 Screenshot count (1-5)" PASS "$SCREENSHOT_COUNT"
elif [[ $SCREENSHOT_COUNT -gt 5 ]]; then
    check "100.3.3 Screenshot count (1-5)" FAIL "$SCREENSHOT_COUNT > 5"
else
    check "100.3.3 Screenshot count (1-5)" FAIL "aucun screenshot trouvé"
fi

# ----- RÉSUMÉ -----
printf "\n${CYAN}════════════════════════════════════════${NC}\n"
printf "${BOLD}Résumé:${NC} "
printf "${GREEN}${PASS} PASS${NC} | "
printf "${YELLOW}${WARN} WARN${NC} | "
printf "${RED}${FAIL} FAIL${NC}\n"
printf "${CYAN}════════════════════════════════════════${NC}\n"

if [[ $FAIL -gt 0 ]]; then
    printf "\n${RED}✗ Assets non conformes — corriger les FAIL avant upload Partner Center${NC}\n"
    exit 1
fi
printf "\n${GREEN}✓ Assets conformes aux politiques 100.3.x — prêts pour upload Partner Center${NC}\n"
exit 0
