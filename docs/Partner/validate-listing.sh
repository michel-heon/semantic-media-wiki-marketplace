#!/usr/bin/env bash
# =============================================================================
# validate-listing.sh - Validation conformité listing Partner Center (T9)
# ADR-803 (titre/marques) · ADR-804 (politiques 100.x) · Issue #4 (T9)
#
# Usage: bash docs/Partner/validate-listing.sh
# Exit 0 si tous critères PASS, exit 1 si un critère FAIL.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SRC="${REPO_ROOT}/docs/Partner/partner-center-questions.md"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

[[ -f "$SRC" ]] || { echo "Source absente: $SRC"; exit 1; }

printf "\n${BOLD}${CYAN}Partner Center listing — validation conformité 100.x${NC}\n"
printf "${CYAN}Source: ${SRC#${REPO_ROOT}/}${NC}\n\n"

RESULTS=$(python3 - "$SRC" << 'PY'
import re, sys, pathlib
src = pathlib.Path(sys.argv[1]).read_text()

def find(pat):
    m = re.search(pat, src, re.DOTALL)
    return m.group(1).strip() if m else None

title    = find(r"## Q3 — Offer listing.*?\*\*Name\*\* \| `([^`]+)`")
summary  = find(r"\*\*Search results summary\*\* \| `([^`]+)`")
plan_sum = find(r"### Plan summary \(\d+ / 100 chars max\)\s*```\s*(.+?)\s*```")
short_d  = find(r"### Short description.*?```\s*(.+?)\s*```\s*### Description")
long_d   = find(r"### Description \(≤ 5 000 chars HTML\)\s*```html\s*(.+?)\s*```")

def emit(label, status, detail=""):
    print(f"{label}|{status}|{detail}")

emit("100.1.2 Title length", "PASS" if title and len(title) <= 50 else "FAIL", f"{len(title or '')}/50")
emit("100.1.2 Search summary length", "PASS" if summary and len(summary) <= 100 else "FAIL", f"{len(summary or '')}/100")
emit("100.1.2 Plan summary length", "PASS" if plan_sum and len(plan_sum) <= 100 else "FAIL", f"{len(plan_sum or '')}/100")
emit("Short description length", "PASS" if short_d and len(short_d) <= 2047 else "FAIL", f"{len(short_d or '')}/2047")
emit("Long description length", "PASS" if long_d and len(long_d) <= 5000 else "FAIL", f"{len(long_d or '')}/5000")

marks = ["azure", "microsoft", "windows", "office", "mediawiki", "wikipedia", "wikimedia"]
for field_name, val in [("title", title), ("search summary", summary)]:
    v = (val or "").lower()
    hit = [m for m in marks if m in v]
    emit(f"100.7.1 No marks in {field_name}",
         "PASS" if not hit else "FAIL",
         f"hits: {hit}" if hit else "none")

fr_chars = set("éèêàçôîûù")
combined = (short_d or "") + (long_d or "")
fr_hit = [c for c in fr_chars if c in combined.lower()]
emit("100.1.4 English-only", "PASS" if not fr_hit else "WARN",
     f"FR chars: {fr_hit}" if fr_hit else "100% EN")

def has_any(text, kws):
    t = text.lower()
    return any(k in t for k in kws)

ld = long_d or ""
emit("100.1.3 Audience identified",
     "PASS" if has_any(ld, ["universities","enterprise","compliance","documentation teams"]) else "FAIL")
emit("100.1.3 Unique value mentioned",
     "PASS" if "knowledge graph" in ld.lower() and "semantic" in ld.lower() else "FAIL")
emit("100.1.3 Prerequisites (VM sizes)",
     "PASS" if "standard_b2ms" in ld.lower() or "standard_d2s" in ld.lower() else "FAIL")
emit("100.1.3 Limitations stated",
     "PASS" if "ssh key" in ld.lower() and "firewall" in ld.lower() else "FAIL")

banned = ["better than","competitor","versus ","vs.","outperforms"]
hit = [b for b in banned if b in combined.lower()]
emit("100.1.3 No comparative marketing", "PASS" if not hit else "FAIL",
     f"hits: {hit}" if hit else "none")
PY
)

PASS=0; FAIL=0; WARN=0
while IFS='|' read -r label status detail; do
    case "$status" in
        PASS) printf "  ${GREEN}✓ PASS${NC} %-44s %s\n" "$label" "$detail"; ((++PASS)) || true ;;
        FAIL) printf "  ${RED}✗ FAIL${NC} %-44s %s\n" "$label" "$detail"; ((++FAIL)) || true ;;
        WARN) printf "  ${YELLOW}⚠ WARN${NC} %-44s %s\n" "$label" "$detail"; ((++WARN)) || true ;;
    esac
done <<< "$RESULTS"

printf "\n${CYAN}════════════════════════════════════════${NC}\n"
printf "${BOLD}Résumé:${NC} "
printf "${GREEN}${PASS} PASS${NC} | "
printf "${YELLOW}${WARN} WARN${NC} | "
printf "${RED}${FAIL} FAIL${NC}\n"
printf "${CYAN}════════════════════════════════════════${NC}\n"

if [[ $FAIL -gt 0 ]]; then
    printf "\n${RED}✗ Validation T9 — corriger les FAIL avant submission${NC}\n"
    exit 1
fi
printf "\n${GREEN}✓ Listing Partner Center conforme aux politiques 100.x${NC}\n"
exit 0
