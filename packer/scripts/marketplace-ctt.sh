#!/usr/bin/env bash
# =============================================================================
# marketplace-ctt.sh - Validation conformité Azure Marketplace (ADR-800)
# ADR-602: Logique extraite du Makefile
# ADR-800: Publication Azure Marketplace VM Offer
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs ANSI (ADR-611)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Compteurs résultats
PASS=0
FAIL=0
WARN=0

# Resource group E2E tests (peut être surchargé par variable d'env)
E2E_RG="${E2E_RG:-rg-smw-marketplace-e2e}"

# -----------------------------------------------------------------------------
# Fonctions utilitaires
# -----------------------------------------------------------------------------

log_test() {
    printf "${CYAN}[TEST]${NC} %s... " "$1"
}

log_pass() {
    printf "${GREEN}✓ PASS${NC}\n"
    ((++PASS)) || true
}

log_fail() {
    printf "${RED}✗ FAIL${NC}"
    [[ -n "${1:-}" ]] && printf " - %s" "$1"
    printf "\n"
    ((++FAIL)) || true
}

log_warn() {
    printf "${YELLOW}⚠ WARN${NC}"
    [[ -n "${1:-}" ]] && printf " - %s" "$1"
    printf "\n"
    ((++WARN)) || true
}

# Exécute une commande sur la VM via az vm run-command
run_on_vm() {
    local vm_name="$1"
    local script="$2"
    local message
    message=$(az vm run-command invoke \
        -g "$E2E_RG" \
        -n "$vm_name" \
        --command-id RunShellScript \
        --scripts "$script" \
        --query 'value[0].message' -o tsv 2>/dev/null | tr -d '\r')

    # Extraire uniquement le contenu de stdout (entre [stdout] et [stderr])
    echo "$message" | sed -n '/\[stdout\]/,/\[stderr\]/{/\[stdout\]/d;/\[stderr\]/d;p;}'
}

# Trouve la VM de test SMW la plus récente
find_test_vm() {
    az vm list -g "$E2E_RG" --query "[?starts_with(name,'test-smw')].name | sort(@) | [-1]" -o tsv 2>/dev/null | tr -d '\r'
}

# -----------------------------------------------------------------------------
# Tests de conformité ADR-800
# -----------------------------------------------------------------------------

test_walinuxagent() {
    local vm="$1"
    log_test "Azure Linux Agent (walinuxagent)"

    local result
    result=$(run_on_vm "$vm" "systemctl is-active walinuxagent 2>/dev/null || echo 'inactive'")

    if echo "$result" | grep -q "active"; then
        log_pass
    else
        log_fail "walinuxagent non actif"
    fi
}

test_cloud_init() {
    local vm="$1"
    log_test "Cloud-init installé"

    local result
    result=$(run_on_vm "$vm" "which cloud-init && echo 'FOUND' || echo 'NOTFOUND'")

    if echo "$result" | grep -q "FOUND"; then
        log_pass
    else
        log_warn "cloud-init recommandé mais non requis"
    fi
}

test_ssh_config() {
    local vm="$1"
    log_test "SSH ClientAliveInterval (0-235)"

    local result
    result=$(run_on_vm "$vm" "grep -E '^ClientAliveInterval' /etc/ssh/sshd_config 2>/dev/null || echo 'DEFAULT'")

    if echo "$result" | grep -qE "ClientAliveInterval[[:space:]]+([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-2][0-9]|23[0-5])$"; then
        log_pass
    elif echo "$result" | grep -q "DEFAULT"; then
        log_warn "ClientAliveInterval non défini (défaut OK)"
    else
        log_fail "ClientAliveInterval hors plage 0-235"
    fi
}

test_root_login() {
    local vm="$1"
    log_test "SSH PermitRootLogin désactivé"

    local result
    result=$(run_on_vm "$vm" "grep -E '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null | head -1 || echo 'DEFAULT'")

    if echo "$result" | grep -qE "PermitRootLogin[[:space:]]+(no|prohibit-password)"; then
        log_pass
    else
        log_warn "PermitRootLogin devrait être 'no'"
    fi
}

test_hyperv_drivers() {
    local vm="$1"
    log_test "Hyper-V drivers (hv_netvsc, hv_storvsc)"

    local result
    result=$(run_on_vm "$vm" "
        netvsc_found=0
        storvsc_found=0

        if lsmod | grep -q 'hv_netvsc'; then netvsc_found=1; fi
        if lsmod | grep -q 'hv_storvsc'; then storvsc_found=1; fi

        if [ \$netvsc_found -eq 0 ]; then
            grep -q 'hv_netvsc.ko' /lib/modules/\$(uname -r)/modules.builtin 2>/dev/null && netvsc_found=1
        fi
        if [ \$storvsc_found -eq 0 ]; then
            grep -q 'hv_storvsc.ko' /lib/modules/\$(uname -r)/modules.builtin 2>/dev/null && storvsc_found=1
        fi

        echo \$((netvsc_found + storvsc_found))
    ")

    if echo "$result" | grep -qE "^2$"; then
        log_pass
    else
        log_fail "Drivers Hyper-V manquants"
    fi
}

test_no_swap_os() {
    local vm="$1"
    log_test "Pas de swap sur disque OS"

    local result
    result=$(run_on_vm "$vm" "grep -v '^#' /etc/fstab 2>/dev/null | grep -i swap || echo 'NOSWAP'")

    if echo "$result" | grep -q "NOSWAP"; then
        log_pass
    else
        log_warn "Swap détecté dans fstab — vérifier si sur OS disk"
    fi
}

test_bash_history() {
    local vm="$1"
    log_test "Bash history nettoyé"

    local result
    result=$(run_on_vm "$vm" "wc -c < /home/*/.bash_history 2>/dev/null | awk '{sum+=\$1} END {print sum+0}'")

    local size
    size=$(echo "$result" | grep -oE '[0-9]+' | tail -1)

    if [[ "${size:-0}" -lt 1024 ]]; then
        log_pass
    else
        log_warn "Bash history > 1KB (${size} bytes)"
    fi
}

test_tls_config() {
    local vm="$1"
    log_test "TLS 1.2+ activé (TLS 1.0/1.1 désactivés)"

    local result
    result=$(run_on_vm "$vm" "grep -E 'MinProtocol.*TLSv1\.[23]' /etc/ssl/openssl.cnf 2>/dev/null || echo 'NOTSET'")

    if echo "$result" | grep -qE "TLSv1\.[23]"; then
        log_pass
    else
        log_warn "MinProtocol TLS non configuré explicitement"
    fi
}

test_dns_resolution() {
    local vm="$1"
    log_test "Résolution DNS externe"

    local result
    result=$(run_on_vm "$vm" "timeout 5 ping -c 1 bing.com >/dev/null 2>&1 && echo 'OK' || echo 'FAIL'")

    if echo "$result" | grep -q "OK"; then
        log_pass
    else
        log_fail "ping bing.com échoué"
    fi
}

test_kernel_params() {
    local vm="$1"
    log_test "Kernel params console série"

    local result
    result=$(run_on_vm "$vm" "cat /proc/cmdline | grep -E 'console=ttyS0|earlyprintk' || echo 'MISSING'")

    if echo "$result" | grep -q "console=ttyS0"; then
        log_pass
    else
        log_warn "console=ttyS0 non trouvé (peut être OK selon GRUB)"
    fi
}

test_no_default_password() {
    local vm="$1"
    log_test "Pas de mot de passe par défaut"

    local empty_pw
    empty_pw=$(run_on_vm "$vm" "grep -E '^[^:]+::' /etc/shadow | wc -l || echo '0'")

    if echo "$empty_pw" | grep -qE "^0"; then
        log_pass
    else
        log_fail "Compte avec mot de passe vide détecté"
    fi
}

test_lisa_no_users() {
    local vm="$1"
    log_test "LISA 200.3.3.8 — Pas d'utilisateurs non-système (UID >= 1000)"

    # Exclure azureuser (créé lors du déploiement par az vm create)
    local result
    result=$(run_on_vm "$vm" "awk -F: '\$3 >= 1000 && \$3 < 65534 && \$1 != \"azureuser\" {print \$1\" (UID=\"\$3\")\"}' /etc/passwd")

    if [[ -z "$result" ]]; then
        log_pass
    else
        log_fail "Utilisateurs non-système trouvés (hors azureuser): $result"
    fi
}

test_php_running() {
    local vm="$1"
    log_test "PHP-FPM actif (SMW)"

    local result
    result=$(run_on_vm "$vm" "systemctl is-active php8.2-fpm 2>/dev/null || echo 'inactive'")

    if echo "$result" | grep -q "^active"; then
        log_pass
    else
        log_fail "php8.2-fpm non actif"
    fi
}

test_apache_running() {
    local vm="$1"
    log_test "Apache2 actif (SMW)"

    local result
    result=$(run_on_vm "$vm" "systemctl is-active apache2 2>/dev/null || echo 'inactive'")

    if echo "$result" | grep -q "^active"; then
        log_pass
    else
        log_fail "apache2 non actif"
    fi
}

test_mysql_running() {
    local vm="$1"
    log_test "MySQL actif (SMW)"

    local result
    result=$(run_on_vm "$vm" "systemctl is-active mysql 2>/dev/null || echo 'inactive'")

    if echo "$result" | grep -q "^active"; then
        log_pass
    else
        log_fail "mysql non actif"
    fi
}

test_mediawiki_accessible() {
    local vm="$1"
    log_test "MediaWiki accessible en HTTP local"

    local result
    result=$(run_on_vm "$vm" "curl -s -o /dev/null -w '%{http_code}' http://localhost/ 2>/dev/null || echo '000'")

    if echo "$result" | grep -qE "^(200|301|302)$"; then
        log_pass
    else
        log_fail "HTTP localhost retourne: $result"
    fi
}

test_cve_usn() {
    local vm="$1"
    log_test "AMAT 200.5.8 — Patches CVE Ubuntu (USN-8284/8292/8293/8306)"

    # Miroir du gate Packer 01-install-base.sh §2.b
    # Source : rapports Partner Center 2026-06-02 et 2026-06-13
    # ADR-300 §9 (Test #16), ADR-619 (DRIFT-000)
    local result
    result=$(run_on_vm "$vm" "
        fail=0
        check() {
            local pkg=\$1 min=\$2
            local cur
            cur=\$(dpkg-query -W -f='\${Version}' \$pkg 2>/dev/null || echo '')
            if [ -z \"\$cur\" ]; then
                echo \"  ? \$pkg : non installé (skip)\"
                return 0
            fi
            if dpkg --compare-versions \"\$cur\" ge \"\$min\"; then
                echo \"  OK \$pkg \$cur >= \$min\"
            else
                echo \"  KO \$pkg \$cur < \$min\"
                fail=1
            fi
        }
        check libgnutls30    '3.7.3-4ubuntu1.9'
        check libarchive13   '3.6.0-1ubuntu1.7'
        check bind9-host     '1:9.18.39-0ubuntu0.22.04.4'
        check bind9-dnsutils '1:9.18.39-0ubuntu0.22.04.4'
        check bind9-libs     '1:9.18.39-0ubuntu0.22.04.4'
        check libwbclient0   '2:4.15.13+dfsg-0ubuntu1.12'
        echo RESULT=\$fail
    ")

    if echo "$result" | grep -qE "RESULT=0$"; then
        log_pass
    else
        log_fail "Au moins un paquet USN sous version requise (voir 01-install-base.sh §2.b)"
        # Afficher les détails pour aider au diagnostic
        echo "$result" | grep -E "^  (KO|OK|\?)" | sed 's/^/    /'
    fi
}

# -----------------------------------------------------------------------------
# Commandes principales
# -----------------------------------------------------------------------------

show_info() {
    printf "\n${BOLD}${CYAN}Azure Marketplace Validation — Semantic MediaWiki (ADR-800)${NC}\n"
    printf "${CYAN}═══════════════════════════════════════════════════════════${NC}\n\n"
    printf "Ce script valide la conformité aux exigences Microsoft Marketplace:\n\n"
    printf "  Conformité Azure Marketplace:\n"
    printf "  • Azure Linux Agent (walinuxagent)\n"
    printf "  • Configuration SSH sécurisée\n"
    printf "  • Drivers Hyper-V\n"
    printf "  • Configuration TLS 1.2+\n"
    printf "  • Résolution DNS\n"
    printf "  • Pas de swap sur OS disk\n"
    printf "  • Bash history nettoyé\n"
    printf "  • Pas de credentials par défaut\n"
    printf "  • AMAT 200.5.8 — Patches CVE Ubuntu (gate USN)\n\n"
    printf "  Tests spécifiques SMW:\n"
    printf "  • PHP 8.2-FPM actif\n"
    printf "  • Apache2 actif\n"
    printf "  • MySQL actif\n"
    printf "  • MediaWiki accessible en HTTP\n\n"
    printf "Usage:\n"
    printf "  make marketplace-validate           # Valide sur VM de test active\n"
    printf "  make marketplace-validate VM=<nom>  # VM spécifique\n"
    printf "  make marketplace-test TEST=<nom>    # Test individuel\n"
    printf "  make marketplace-tests              # Lister les tests\n\n"
    printf "E2E_RG: ${CYAN}${E2E_RG}${NC}\n"
}

run_validate() {
    local vm_name="${1:-}"

    # Trouver VM de test si non spécifiée
    if [[ -z "$vm_name" ]]; then
        printf "${CYAN}Recherche VM de test SMW...${NC}\n"
        vm_name=$(find_test_vm)

        if [[ -z "$vm_name" ]]; then
            printf "${RED}✗ Aucune VM de test trouvée dans ${E2E_RG}${NC}\n"
            printf "Créez une VM avec: make vm-ensure\n"
            exit 1
        fi
    fi

    printf "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${BOLD}${CYAN}║  Azure Marketplace Certification Tests — SMW (ADR-800)       ║${NC}\n"
    printf "${BOLD}${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}\n"
    printf "${CYAN}║${NC} VM: ${BOLD}${vm_name}${NC}\n"
    printf "${CYAN}║${NC} RG: ${BOLD}${E2E_RG}${NC}\n"
    printf "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n\n"

    # Tests conformité Azure Marketplace
    printf "${BOLD}Conformité Azure Marketplace:${NC}\n"
    test_walinuxagent "$vm_name"
    test_cloud_init "$vm_name"
    test_ssh_config "$vm_name"
    test_root_login "$vm_name"
    test_hyperv_drivers "$vm_name"
    test_no_swap_os "$vm_name"
    test_bash_history "$vm_name"
    test_tls_config "$vm_name"
    test_dns_resolution "$vm_name"
    test_kernel_params "$vm_name"
    test_no_default_password "$vm_name"
    test_lisa_no_users "$vm_name"
    test_cve_usn "$vm_name"

    # Tests applicatifs SMW
    printf "\n${BOLD}Stack applicative SMW:${NC}\n"
    test_php_running "$vm_name"
    test_apache_running "$vm_name"
    test_mysql_running "$vm_name"
    test_mediawiki_accessible "$vm_name"

    # Résumé
    printf "\n${CYAN}════════════════════════════════════════${NC}\n"
    printf "${BOLD}Résumé:${NC} "
    printf "${GREEN}${PASS} PASS${NC} | "
    printf "${YELLOW}${WARN} WARN${NC} | "
    printf "${RED}${FAIL} FAIL${NC}\n"
    printf "${CYAN}════════════════════════════════════════${NC}\n"

    if [[ $FAIL -gt 0 ]]; then
        printf "\n${RED}✗ Certification échouée — corriger les erreurs FAIL${NC}\n"
        exit 1
    elif [[ $WARN -gt 0 ]]; then
        printf "\n${YELLOW}⚠ Certification conditionnelle — vérifier les WARN${NC}\n"
        exit 0
    else
        printf "\n${GREEN}✓ Tous les tests passés — prêt pour certification Azure Marketplace${NC}\n"
        exit 0
    fi
}

# Liste des tests disponibles
AVAILABLE_TESTS=(
    "walinuxagent:Azure Linux Agent actif"
    "cloud_init:Cloud-init installé"
    "ssh_config:SSH ClientAliveInterval (0-235)"
    "root_login:SSH PermitRootLogin désactivé"
    "hyperv_drivers:Drivers Hyper-V chargés"
    "no_swap_os:Pas de swap sur OS disk"
    "bash_history:Bash history nettoyé"
    "tls_config:TLS 1.2+ configuré"
    "dns_resolution:Résolution DNS externe"
    "kernel_params:Kernel params console série"
    "no_default_password:Pas de mot de passe par défaut"
    "lisa_no_users:LISA 200.3.3.8 — Pas d'utilisateurs UID >= 1000"
    "cve_usn:AMAT 200.5.8 — Patches CVE Ubuntu (USN-8284/8292/8293/8306)"
    "php_running:PHP 8.2-FPM actif"
    "apache_running:Apache2 actif"
    "mysql_running:MySQL actif"
    "mediawiki_accessible:MediaWiki HTTP localhost"
)

list_tests() {
    printf "${BOLD}${CYAN}Tests disponibles:${NC}\n\n"
    for test_entry in "${AVAILABLE_TESTS[@]}"; do
        local name="${test_entry%%:*}"
        local desc="${test_entry#*:}"
        printf "  ${GREEN}%-22s${NC} %s\n" "$name" "$desc"
    done
    printf "\n"
}

run_single_test() {
    local test_name="${1:-}"
    local vm_name="${2:-}"

    if [[ -z "$test_name" ]]; then
        printf "${RED}✗ Nom du test requis${NC}\n"
        list_tests
        exit 1
    fi

    # Trouver VM de test si non spécifiée
    if [[ -z "$vm_name" ]]; then
        printf "${CYAN}Recherche VM de test SMW...${NC}\n"
        vm_name=$(find_test_vm)

        if [[ -z "$vm_name" ]]; then
            printf "${RED}✗ Aucune VM de test trouvée dans ${E2E_RG}${NC}\n"
            exit 1
        fi
    fi

    printf "${CYAN}VM:${NC} ${BOLD}${vm_name}${NC}\n\n"

    case "$test_name" in
        walinuxagent)        test_walinuxagent "$vm_name" ;;
        cloud_init)          test_cloud_init "$vm_name" ;;
        ssh_config)          test_ssh_config "$vm_name" ;;
        root_login)          test_root_login "$vm_name" ;;
        hyperv_drivers)      test_hyperv_drivers "$vm_name" ;;
        no_swap_os)          test_no_swap_os "$vm_name" ;;
        bash_history)        test_bash_history "$vm_name" ;;
        tls_config)          test_tls_config "$vm_name" ;;
        dns_resolution)      test_dns_resolution "$vm_name" ;;
        kernel_params)       test_kernel_params "$vm_name" ;;
        no_default_password) test_no_default_password "$vm_name" ;;
        lisa_no_users)       test_lisa_no_users "$vm_name" ;;
        cve_usn)             test_cve_usn "$vm_name" ;;
        php_running)         test_php_running "$vm_name" ;;
        apache_running)      test_apache_running "$vm_name" ;;
        mysql_running)       test_mysql_running "$vm_name" ;;
        mediawiki_accessible) test_mediawiki_accessible "$vm_name" ;;
        *)
            printf "${RED}✗ Test inconnu: ${test_name}${NC}\n\n"
            list_tests
            exit 1
            ;;
    esac

    if [[ $FAIL -gt 0 ]]; then
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

case "${1:-}" in
    info)
        show_info
        ;;
    validate)
        run_validate "${2:-}"
        ;;
    test)
        run_single_test "${2:-}" "${3:-}"
        ;;
    list)
        list_tests
        ;;
    all)
        run_validate "${2:-}"
        ;;
    *)
        printf "Usage: %s <commande> [options]\n\n" "$(basename "$0")"
        printf "${BOLD}Commandes:${NC}\n"
        printf "  ${GREEN}info${NC}                       Afficher infos CTT\n"
        printf "  ${GREEN}validate${NC} [vm_name]         Exécuter tous les tests\n"
        printf "  ${GREEN}all${NC} [vm_name]              Alias pour validate\n"
        printf "  ${GREEN}test${NC} <nom> [vm_name]       Exécuter un test spécifique\n"
        printf "  ${GREEN}list${NC}                       Lister les tests disponibles\n"
        exit 1
        ;;
esac
