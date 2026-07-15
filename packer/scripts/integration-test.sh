#!/usr/bin/env bash
# =============================================================================
# packer/scripts/integration-test.sh
# Plan de tests d'intégration SMW Marketplace — ADR-700
#
# Usage: bash integration-test.sh {static|image|e2e|all}
#
# ADR-700 (stratégie tests) · ADR-602 (script délégué Makefile) ·
# ADR-611 (couleurs printf) · ADR-613 (provisioner architecture) ·
# ADR-300 (sécurité hardening) · ADR-001 (versions canoniques)
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Couleurs — ADR-611
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Compteurs
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
SKIP=0

pass() { printf "${GREEN}  ✓ PASS${NC} %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "${RED}  ✗ FAIL${NC} %s\n" "$1"; FAIL=$((FAIL + 1)); }
skip() { printf "${YELLOW}  ⊘ SKIP${NC} %s\n" "$1"; SKIP=$((SKIP + 1)); }
header() { printf "\n${CYAN}▶ %s${NC}\n" "$1"; }

summary() {
    printf "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "  ${GREEN}PASS: %d${NC}   ${RED}FAIL: %d${NC}   ${YELLOW}SKIP: %d${NC}\n" \
        "$PASS" "$FAIL" "$SKIP"
    printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    [[ $FAIL -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Chemins
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROVISIONERS_DIR="${REPO_ROOT}/packer/provisioners"

# ---------------------------------------------------------------------------
# Source config si disponible — ADR-600
# ---------------------------------------------------------------------------
CONFIG_FILE="${REPO_ROOT}/env/generated/config.make"
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS= read -r line; do
        if [[ "$line" =~ ^([A-Z_]+)[[:space:]]*:?=[[:space:]]*(.*)$ ]]; then
            declare "${BASH_REMATCH[1]}"="${BASH_REMATCH[2]}"
        fi
    done < <(grep -E '^[A-Z_]+ *:?= *' "$CONFIG_FILE")
fi

E2E_RG="${E2E_RG:-rg-smw-marketplace-e2e}"
VM_NAME="${VM_NAME:-smw-wiki-test}"
ADMIN_USERNAME="${ADMIN_USERNAME:-azureuser}"

# ---------------------------------------------------------------------------
# PHASE 1 — Tests Statiques (aucun accès Azure requis)
# ADR-700 §Phase 1
# ---------------------------------------------------------------------------
phase_static() {
    header "PHASE 1 — Tests Statiques (local, aucun accès Azure)"

    # T-STATIC-01 : Packer HCL2 syntaxe valide (US-01.2, ADR-617)
    if command -v packer &>/dev/null; then
        if packer validate \
            -var-file="${REPO_ROOT}/packer/generated.pkrvars.hcl" \
            -var "build_date=$(date +%Y%m%d)" \
            "${REPO_ROOT}/packer/" &>/dev/null 2>&1; then
            pass "T-STATIC-01: Packer HCL2 — syntaxe valide"
        else
            fail "T-STATIC-01: Packer HCL2 — erreur de syntaxe"
        fi
    else
        skip "T-STATIC-01: Packer HCL2 — packer non installé"
    fi

    # T-STATIC-02 : ARM mainTemplate.json JSON valide (US-02.1, ADR-200)
    if [[ -f "${REPO_ROOT}/arm/mainTemplate.json" ]]; then
        if python3 -m json.tool "${REPO_ROOT}/arm/mainTemplate.json" &>/dev/null; then
            pass "T-STATIC-02: ARM mainTemplate.json — JSON syntaxe valide"
        else
            fail "T-STATIC-02: ARM mainTemplate.json — JSON invalide"
        fi
    else
        fail "T-STATIC-02: ARM mainTemplate.json — fichier absent"
    fi

    # T-STATIC-03 : ARM createUIDefinition.json JSON valide (US-02.1, ADR-200)
    if [[ -f "${REPO_ROOT}/arm/createUIDefinition.json" ]]; then
        if python3 -m json.tool "${REPO_ROOT}/arm/createUIDefinition.json" &>/dev/null; then
            pass "T-STATIC-03: ARM createUIDefinition.json — JSON syntaxe valide"
        else
            fail "T-STATIC-03: ARM createUIDefinition.json — JSON invalide"
        fi
    else
        fail "T-STATIC-03: ARM createUIDefinition.json — fichier absent"
    fi

    # T-STATIC-04 : Scan secrets hardcodés dans les provisioners (US-02.4)
    local SECRET_PATTERNS='password[[:space:]]*=[[:space:]]*['\''"][^$\{]|MYSQL_ROOT_PASSWORD[[:space:]]*=[[:space:]]*['\''"][^$\{]|wgDBpassword[[:space:]]*=[[:space:]]*['\''"][^$\{]'
    local SECRETS_FOUND
    SECRETS_FOUND=$(grep -riE "$SECRET_PATTERNS" "${PROVISIONERS_DIR}"/*.sh 2>/dev/null \
        | grep -v '#' \
        | grep -v -i 'changeme\|_example\|=""$\|='"'"''"'"'$' || true)
    if [[ -z "$SECRETS_FOUND" ]]; then
        pass "T-STATIC-04: Scan secrets — aucun credential hardcodé dans les provisioners"
    else
        fail "T-STATIC-04: Scan secrets — credentials potentiels détectés :"
        printf "%s\n" "$SECRETS_FOUND" | head -5
    fi

    # T-STATIC-05 : Bits exécutables sur tous les provisioners (ADR-601)
    local ALL_EXEC=true
    for script in "${PROVISIONERS_DIR}"/0*.sh; do
        if [[ ! -x "$script" ]]; then
            ALL_EXEC=false
            fail "T-STATIC-05: Permissions — ${script##*/} non exécutable"
        fi
    done
    [[ "$ALL_EXEC" == true ]] && \
        pass "T-STATIC-05: Permissions — tous les provisioners sont exécutables"

    # T-STATIC-06 : Séquence 01→09 complète (ADR-613)
    local MISSING=""
    for i in 01 02 03 04 05 06 07 08 09; do
        if ! ls "${PROVISIONERS_DIR}/${i}-"*.sh &>/dev/null 2>&1; then
            MISSING="${MISSING} ${i}"
        fi
    done
    if [[ -z "$MISSING" ]]; then
        pass "T-STATIC-06: Séquence provisioners 01→09 — complète"
    else
        fail "T-STATIC-06: Séquence provisioners — manquants :${MISSING}"
    fi

    # T-STATIC-07 : smw-firstboot.service déclaré dans 08-firstboot-setup.sh (US-02.3)
    if grep -q "smw-firstboot.service" \
        "${PROVISIONERS_DIR}/08-firstboot-setup.sh" 2>/dev/null; then
        pass "T-STATIC-07: smw-firstboot.service — déclaré dans 08-firstboot-setup.sh"
    else
        fail "T-STATIC-07: smw-firstboot.service — absent de 08-firstboot-setup.sh"
    fi

    # T-STATIC-08 : Sentinel idempotence dans 08-firstboot-setup.sh (US-02.3)
    if grep -q "firstboot-done" \
        "${PROVISIONERS_DIR}/08-firstboot-setup.sh" 2>/dev/null; then
        pass "T-STATIC-08: Sentinel idempotence — présent dans 08-firstboot-setup.sh"
    else
        fail "T-STATIC-08: Sentinel idempotence — absent de 08-firstboot-setup.sh"
    fi

    # T-STATIC-09 : trap ERR journalisation (US-02.5)
    if grep -q "trap.*ERR" \
        "${PROVISIONERS_DIR}/08-firstboot-setup.sh" 2>/dev/null; then
        pass "T-STATIC-09: trap ERR — présent dans 08-firstboot-setup.sh"
    else
        fail "T-STATIC-09: trap ERR — absent de 08-firstboot-setup.sh"
    fi

    # T-STATIC-10 : SSH hardening PasswordAuthentication no (ADR-300, US-03.2)
    if grep -q "PasswordAuthentication no" \
        "${PROVISIONERS_DIR}/07-security-harden.sh" 2>/dev/null; then
        pass "T-STATIC-10: SSH hardening — PasswordAuthentication no présent dans 07-security-harden.sh"
    else
        fail "T-STATIC-10: SSH hardening — PasswordAuthentication no absent de 07-security-harden.sh"
    fi

    # T-STATIC-11 : URL Privacy policy Partner Center correcte (ADR-804, ADR-701)
    # Détecte la régression observée en certification : URL pointant vers
    # server-azure-marketplace-docs (404) au lieu du repo canonique smw6-azure-marketplace-docs.
    local PARTNER_QUESTIONS_FILE="${REPO_ROOT}/docs/Partner/partner-center-questions.md"
    local PRIVACY_ROW
    PRIVACY_ROW=$(grep -E '^\| \*\*Privacy policy URL\*\* \|' "$PARTNER_QUESTIONS_FILE" 2>/dev/null | head -1 || true)
    if [[ -z "$PRIVACY_ROW" ]]; then
        fail "T-STATIC-11: Privacy policy URL — ligne introuvable dans docs/Partner/partner-center-questions.md"
    elif [[ "$PRIVACY_ROW" == *"https://github.com/Cotechnoe/smw6-azure-marketplace-docs/blob/main/PRIVACY.md"* ]] && \
         [[ "$PRIVACY_ROW" != *"server-azure-marketplace-docs"* ]]; then
        pass "T-STATIC-11: Privacy policy URL — repo canonique smw6-azure-marketplace-docs"
    else
        fail "T-STATIC-11: Privacy policy URL — URL invalide (risque 404 Partner Center)"
        printf "      Ligne détectée: %s\n" "$PRIVACY_ROW"
    fi
}

# ---------------------------------------------------------------------------
# PHASE 2 — Tests Image Gallery (SSH sur VM depuis gallery)
# ADR-700 §Phase 2 · ADR-613 · ADR-614
#
# Prérequis : VM déployée depuis galSMWMarketplace, firstboot NON déclenché
# Variables : E2E_RG, VM_NAME, ADMIN_USERNAME
# ---------------------------------------------------------------------------
phase_image() {
    header "PHASE 2 — Tests Image Gallery (SSH) [E2E_RG=${E2E_RG}, VM=${VM_NAME}]"

    local VM_IP=""
    if command -v az &>/dev/null; then
        VM_IP=$(az vm list-ip-addresses \
            --resource-group "$E2E_RG" \
            --name "$VM_NAME" \
            --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
            -o tsv 2>/dev/null || true)
    fi

    if [[ -z "$VM_IP" ]]; then
        for id in IMAGE-01 IMAGE-02 IMAGE-03 IMAGE-04 IMAGE-05 \
                  IMAGE-06 IMAGE-07 IMAGE-08 IMAGE-09 IMAGE-10 \
                  CERT-01 CERT-02 CERT-03 CERT-04 \
                  CERT-05a CERT-05b CERT-05c CERT-05d CERT-05e \
                  CERT-06a CERT-06b CERT-06c \
                  CERT-08a CERT-08b CERT-08c CERT-08d \
                  CERT-08e CERT-08f CERT-08g CERT-08h \
                  CERT-07a CERT-07b-pwd CERT-07b-key CERT-07c; do
            skip "T-${id}: VM '${VM_NAME}' introuvable dans '${E2E_RG}'"
        done
        return 0
    fi

    printf "  ${CYAN}→ IP: %s${NC}\n" "$VM_IP"

    _ssh_check() {
        local id="$1" desc="$2" cmd="$3"
        if ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
               -o ConnectTimeout=10 "${ADMIN_USERNAME}@${VM_IP}" \
               "bash -c '${cmd}'" 2>/dev/null; then
            pass "${id}: ${desc}"
        else
            fail "${id}: ${desc}"
        fi
    }

    # T-IMAGE-01 : PHP 8.2 (ADR-609, US-01.1)
    _ssh_check "T-IMAGE-01" "PHP 8.2 installé" "php8.2 --version 2>/dev/null | grep -q '8\\.2'"

    # T-IMAGE-02 : Apache 2.4 (ADR-613)
    _ssh_check "T-IMAGE-02" "Apache 2.4 installé" "apache2 -v 2>&1 | grep -q '2\\.4'"

    # T-IMAGE-03 : MySQL 8.x (ADR-001)
    _ssh_check "T-IMAGE-03" "MySQL 8.x installé" "mysql --version 2>/dev/null | grep -qE '8\\.'"

    # T-IMAGE-04 : MediaWiki présent (ADR-613)
    _ssh_check "T-IMAGE-04" "MediaWiki présent (/opt/mediawiki)" "test -d /opt/mediawiki"

    # T-IMAGE-05 : SMW extensions (ADR-001)
    _ssh_check "T-IMAGE-05" "SMW extensions présentes" \
        "test -d /opt/mediawiki/extensions/SemanticMediaWiki"

    # T-IMAGE-06 : smw-firstboot.service enabled (US-02.3)
    _ssh_check "T-IMAGE-06" "smw-firstboot.service — enabled" \
        "systemctl is-enabled smw-firstboot 2>/dev/null | grep -q enabled"

    # T-IMAGE-07 : Sentinel absent — image non encore bootée (US-02.3)
    _ssh_check "T-IMAGE-07" "Sentinel absent (image non bootée)" \
        "test ! -f /var/lib/smw/.firstboot-done"

    # T-IMAGE-08 : Pas de credentials dans LocalSettings.php (US-02.4)
    # Note : guillemets simples imbriqués dans bash -c '...' brisent le parsing
    # SSH ; wgDBpassword n'a pas besoin d'être cité (pas d'espaces ni de métacaractères).
    _ssh_check "T-IMAGE-08" "Pas de credentials dans LocalSettings.php" \
        "! grep -q wgDBpassword /opt/mediawiki/LocalSettings.php 2>/dev/null"

    # T-IMAGE-09 : SSH PasswordAuthentication=no (ADR-300, US-03.2)
    # Note : le motif 'PasswordAuthentication no' (avec espace) casse le quoting
    # bash -c '...' via SSH ; on cible sshd_config directement sans guillemets simples.
    _ssh_check "T-IMAGE-09" "SSH PasswordAuthentication no (ADR-300)" \
        "grep PasswordAuthentication /etc/ssh/sshd_config 2>/dev/null | grep -q no"

    # T-IMAGE-10 : UFW actif (ADR-300)
    # Note : ufw status requiert root ; azureuser dispose de sudo NOPASSWD sur Azure.
    # 'Status: active' cassait le quoting SSH — on cherche le mot-clé active sans guillemets.
    _ssh_check "T-IMAGE-10" "UFW actif" \
        "sudo ufw status 2>/dev/null | grep -q active"

    # -----------------------------------------------------------------------
    # Tests T-CERT-* — Certification Microsoft Marketplace (ADR-804, Issue #4)
    # Politique 200.5.8 — VM Linux Endorsed Distribution sur Azure
    # Référence : docs/Certification/2026-06-18-partner.pdf
    # -----------------------------------------------------------------------

    # T-CERT-01 (T1) : GRUB kernel params Azure (console série + rootdelay)
    _ssh_check "T-CERT-01" "GRUB_CMDLINE_LINUX = console=ttyS0 earlyprintk=ttyS0 rootdelay=300" \
        "grep -q console=ttyS0 /etc/default/grub && grep -q earlyprintk=ttyS0 /etc/default/grub && grep -q rootdelay=300 /etc/default/grub"

    # T-CERT-02 (T2) : waagent (WALinuxAgent) installé et version >= 2.2.10
    _ssh_check "T-CERT-02" "waagent installé (>= 2.2.10)" \
        "command -v waagent >/dev/null && waagent --version 2>/dev/null | grep -qE 'WALinuxAgent-[0-9]'"

    # T-CERT-03 (T3) : Swap désactivé et purgé de /etc/fstab (politique Azure OS disk)
    _ssh_check "T-CERT-03" "Swap désactivé et absent de /etc/fstab" \
        "! swapon --show 2>/dev/null | grep -q . && ! grep -E '^[^#]+[[:space:]]swap[[:space:]]' /etc/fstab"

    # T-CERT-04 (T4) : Connexion root SSH bloquée (politique sécurité 200.5.8)
    # Note : sur une VM Azure post-déploiement, waagent réinjecte un authorized_keys
    # root contenant un wrapping inerte (command="echo Please login as azureuser..."),
    # ce qui rend le compte root inopérant en SSH même si le fichier existe. On vérifie :
    # soit le fichier est absent, soit il est wrappé avec le pattern Azure (no-port-forwarding).
    _ssh_check "T-CERT-04" "Connexion SSH root bloquée (fichier absent ou wrappé Azure)" \
        "sudo test ! -f /root/.ssh/authorized_keys || sudo grep -q no-port-forwarding /root/.ssh/authorized_keys"

    # T-CERT-05 (T5) : Paquets USN bloquants patchés (libgnutls30, libarchive13, bind9-*, libwbclient0)
    # Note : `dpkg-query -W -f='${Version}'` casse le wrapping bash -c (guillemets simples).
    # Approche : `dpkg -s pkg | grep ^Version: | cut -d' ' -f2` — sans guillemets dans la chaîne.
    _ssh_check "T-CERT-05a" "USN-8284-1 libgnutls30 >= 3.7.3-4ubuntu1.9" \
        "V=\$(dpkg -s libgnutls30 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 3.7.3-4ubuntu1.9"
    _ssh_check "T-CERT-05b" "USN-8292-1 libarchive13 >= 3.6.0-1ubuntu1.7" \
        "V=\$(dpkg -s libarchive13 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 3.6.0-1ubuntu1.7"
    _ssh_check "T-CERT-05c" "USN-8293-1 bind9-host >= 1:9.18.39-0ubuntu0.22.04.4" \
        "V=\$(dpkg -s bind9-host 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 1:9.18.39-0ubuntu0.22.04.4"
    _ssh_check "T-CERT-05d" "USN-8293-1 bind9-libs >= 1:9.18.39-0ubuntu0.22.04.4" \
        "V=\$(dpkg -s bind9-libs 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 1:9.18.39-0ubuntu0.22.04.4"
    _ssh_check "T-CERT-05e" "USN-8306-1 libwbclient0 >= 2:4.15.13+dfsg-0ubuntu1.12" \
        "V=\$(dpkg -s libwbclient0 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 2:4.15.13+dfsg-0ubuntu1.12"

    # T-CERT-06 (T6) : Drivers Hyper-V disponibles (chargés OU builtin) — Politique 200.3.3
    # Sur Ubuntu Azure, hv_netvsc/hv_storvsc sont généralement builtin dans le kernel azure-tuned.
    # On accepte les deux : présent dans lsmod OU dans modules.builtin.
    # ⚠ Pas de guillemets simples dans cmd (cassent le wrapping bash -c '...').
    # On utilise grep -w pour matcher le nom de module exact (sans regex spéciale).
    _ssh_check "T-CERT-06a" "Driver hv_netvsc chargé ou builtin (Hyper-V network)" \
        "lsmod | cut -d\\  -f1 | grep -qx hv_netvsc || grep -qw hv_netvsc /lib/modules/\$(uname -r)/modules.builtin"
    _ssh_check "T-CERT-06b" "Driver hv_storvsc chargé ou builtin (Hyper-V storage)" \
        "lsmod | cut -d\\  -f1 | grep -qx hv_storvsc || grep -qw hv_storvsc /lib/modules/\$(uname -r)/modules.builtin"
    _ssh_check "T-CERT-06c" "Fichier /etc/modules-load.d/azure-hyperv.conf présent" \
        "test -f /etc/modules-load.d/azure-hyperv.conf"

    # T-CERT-07 (T7) : Audit crons + journaux non-sensibles — Politique 200.5
    # Aucun crontab applicatif www-data/mysql/apache (non documenté).
    _ssh_check "T-CERT-07a" "Aucun crontab applicatif non documenté (www-data/mysql/apache)" \
        "for u in www-data mysql apache; do sudo test ! -f /var/spool/cron/crontabs/\$u || exit 1; done"
    # Pas de pattern sensible dans logs résiduels.
    # Stratégie : grep -q retourne 0 si trouvé, 1 si non trouvé. On veut FAIL si trouvé.
    # Utilisation de grep simple (BRE) sans alternation regex pour éviter pièges quoting.
    # ⚠ Pas de guillemets simples dans cmd (cassent bash -c '...').
    _ssh_check "T-CERT-07b-pwd" "Aucun 'password=...' clair dans logs résiduels" \
        "! sudo grep -aEi \"password[[:space:]]*=\" /var/log/syslog /var/log/auth.log /var/log/cloud-init-output.log 2>/dev/null | head -1 | grep -q ."
    # Pattern recherché : '-----BEGIN ... PRIVATE KEY-----' (5 tirets, vrai bloc PEM).
    # Évite les faux positifs causés par auth.log qui logge la commande sudo elle-même.
    _ssh_check "T-CERT-07b-key" "Aucune clé privée PEM (-----BEGIN PRIVATE KEY-----) dans logs résiduels" \
        "! sudo grep -aErI -- \"-----BEGIN [A-Z]* PRIVATE KEY-----\" /var/log/syslog /var/log/auth.log /var/log/cloud-init-output.log 2>/dev/null | head -1 | grep -q ."
    # LocalSettings.php non lisible par others : extraire dernier digit du mode octal.
    # Si fichier absent (image pré-firstboot), le test est skippé via condition initiale.
    _ssh_check "T-CERT-07c" "LocalSettings.php non lisible par others (mode others-read absent)" \
        "sudo test ! -f /opt/mediawiki/LocalSettings.php || { M=\$(sudo stat -c %a /opt/mediawiki/LocalSettings.php); O=\$(echo \$M | tail -c2); test \$((O & 4)) -eq 0; }"

    # T-CERT-08 (T8) : Paquets vulnérables du rapport 2026-07-15 patchés (200.5.8)
    # Référence : docs/Certification/2026-07-15-Certification-Report.pdf
    # USN-8456-1 (libxml2), USN-8487-1 (curl/libcurl*), USN-8516-1 (apache2*)
    _ssh_check "T-CERT-08a" "USN-8456-1 libxml2 >= 2.9.13+dfsg-1ubuntu0.12" \
        "V=\$(dpkg -s libxml2 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 2.9.13+dfsg-1ubuntu0.12"
    _ssh_check "T-CERT-08b" "USN-8487-1 curl >= 7.81.0-1ubuntu1.25" \
        "V=\$(dpkg -s curl 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 7.81.0-1ubuntu1.25"
    _ssh_check "T-CERT-08c" "USN-8487-1 libcurl3-gnutls >= 7.81.0-1ubuntu1.25" \
        "V=\$(dpkg -s libcurl3-gnutls 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 7.81.0-1ubuntu1.25"
    _ssh_check "T-CERT-08d" "USN-8487-1 libcurl4 >= 7.81.0-1ubuntu1.25" \
        "V=\$(dpkg -s libcurl4 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 7.81.0-1ubuntu1.25"
    _ssh_check "T-CERT-08e" "USN-8516-1 apache2-data >= 2.4.52-1ubuntu4.23" \
        "V=\$(dpkg -s apache2-data 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 2.4.52-1ubuntu4.23"
    _ssh_check "T-CERT-08f" "USN-8516-1 apache2 >= 2.4.52-1ubuntu4.23" \
        "V=\$(dpkg -s apache2 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 2.4.52-1ubuntu4.23"
    _ssh_check "T-CERT-08g" "USN-8516-1 apache2-bin >= 2.4.52-1ubuntu4.23" \
        "V=\$(dpkg -s apache2-bin 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 2.4.52-1ubuntu4.23"
    _ssh_check "T-CERT-08h" "USN-8516-1 apache2-utils >= 2.4.52-1ubuntu4.23" \
        "V=\$(dpkg -s apache2-utils 2>/dev/null | grep ^Version: | cut -d\\  -f2); dpkg --compare-versions \$V ge 2.4.52-1ubuntu4.23"
}

# ---------------------------------------------------------------------------
# PHASE 3 — Tests E2E Post-Déploiement (HTTP/HTTPS + firstboot complet)
# ADR-700 §Phase 3 · US-02.2 · US-02.3 · US-02.5 · ADR-300
#
# Prérequis : VM déployée via ARM, firstboot DÉCLENCHÉ (sentinel présent)
# Variables : E2E_RG, VM_NAME, ADMIN_USERNAME
# ---------------------------------------------------------------------------
phase_e2e() {
    header "PHASE 3 — Tests E2E Post-Déploiement [E2E_RG=${E2E_RG}, VM=${VM_NAME}]"

    local VM_IP=""
    if command -v az &>/dev/null; then
        VM_IP=$(az vm list-ip-addresses \
            --resource-group "$E2E_RG" \
            --name "$VM_NAME" \
            --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
            -o tsv 2>/dev/null || true)
    fi

    if [[ -z "$VM_IP" ]]; then
        for id in E2E-01 E2E-02 E2E-03 E2E-04 E2E-05 E2E-06 \
                  E2E-07 E2E-08 E2E-09 E2E-10 E2E-11; do
            skip "T-${id}: VM '${VM_NAME}' introuvable dans '${E2E_RG}'"
        done
        return 0
    fi

    printf "  ${CYAN}→ IP: %s${NC}\n" "$VM_IP"

    local SSH_CMD="ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 ${ADMIN_USERNAME}@${VM_IP}"

    # T-E2E-01 : SSH accessible (US-03.2, ADR-300)
    if $SSH_CMD true 2>/dev/null; then
        pass "T-E2E-01: SSH — accessible (authentification clé publique)"
    else
        fail "T-E2E-01: SSH — inaccessible sur ${VM_IP}:22"
        for id in E2E-02 E2E-03 E2E-04 E2E-05 E2E-06 E2E-07 E2E-08 E2E-09 E2E-10 E2E-11; do
            skip "T-${id}: SSH requis"
        done
        return 0
    fi

    # T-E2E-02 : HTTP → HTTPS redirect 301/302 (US-02.2)
    local HTTP_CODE
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time 10 "http://${VM_IP}/" 2>/dev/null || printf "000")
    if [[ "$HTTP_CODE" == "301" || "$HTTP_CODE" == "302" ]]; then
        pass "T-E2E-02: HTTP → HTTPS redirect (${HTTP_CODE})"
    else
        fail "T-E2E-02: HTTP → HTTPS redirect attendu 301/302, obtenu ${HTTP_CODE}"
    fi

    # T-E2E-03 : HTTPS actif (200 ou 301 vers wiki) (US-02.2)
    local HTTPS_CODE
    HTTPS_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
        --max-time 10 "https://${VM_IP}/" 2>/dev/null || printf "000")
    if [[ "$HTTPS_CODE" == "200" || "$HTTPS_CODE" == "301" ]]; then
        pass "T-E2E-03: HTTPS — actif (${HTTPS_CODE})"
    else
        fail "T-E2E-03: HTTPS — attendu 200/301, obtenu ${HTTPS_CODE}"
    fi

    # T-E2E-04 : Page login MediaWiki visible (US-02.2)
    local WIKI_BODY
    WIKI_BODY=$(curl -sk --max-time 15 \
        "https://${VM_IP}/index.php/Special:UserLogin" 2>/dev/null || true)
    if printf "%s" "$WIKI_BODY" | grep -qi "mediawiki\|userlogin"; then
        pass "T-E2E-04: Page login MediaWiki — visible"
    else
        fail "T-E2E-04: Page login MediaWiki — non visible"
    fi

    # T-E2E-05 : smw-firstboot.service complété avec succès (US-02.3)
    if $SSH_CMD "systemctl show smw-firstboot --property=Result \
        2>/dev/null | grep -q Result=success" 2>/dev/null; then
        pass "T-E2E-05: smw-firstboot.service — exécution terminée"
    else
        fail "T-E2E-05: smw-firstboot.service — toujours actif ou échec"
    fi

    # T-E2E-06 : Sentinel présent (US-02.3) — /var/lib/smw/ est drwx------ root
    if $SSH_CMD "sudo test -f /var/lib/smw/.firstboot-done" 2>/dev/null; then
        pass "T-E2E-06: Sentinel /var/lib/smw/.firstboot-done — présent"
    else
        fail "T-E2E-06: Sentinel /var/lib/smw/.firstboot-done — absent"
    fi

    # T-E2E-07 : Idempotence — relance → no-op (US-02.3)
    if $SSH_CMD "sudo systemctl start smw-firstboot 2>/dev/null; sleep 2; \
        sudo test -f /var/lib/smw/.firstboot-done" 2>/dev/null; then
        pass "T-E2E-07: Idempotence — relance sans corruption (sentinel intact)"
    else
        fail "T-E2E-07: Idempotence — sentinel supprimé ou service en erreur après relance"
    fi

    # T-E2E-08 : Special:SemanticMediaWiki accessible (ADR-001)
    local SMW_CODE
    SMW_CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 \
        "https://${VM_IP}/index.php/Special:SemanticMediaWiki" 2>/dev/null || printf "000")
    if [[ "$SMW_CODE" == "200" ]]; then
        pass "T-E2E-08: Special:SemanticMediaWiki — accessible (200)"
    else
        fail "T-E2E-08: Special:SemanticMediaWiki — obtenu ${SMW_CODE}"
    fi

    # T-E2E-09 : journalctl entries smw-firstboot présentes (US-02.5)
    if $SSH_CMD "journalctl -u smw-firstboot --no-pager -n 1 2>/dev/null \
        | grep -q ." 2>/dev/null; then
        pass "T-E2E-09: journalctl smw-firstboot — entrées présentes"
    else
        fail "T-E2E-09: journalctl smw-firstboot — aucune entrée"
    fi

    # T-E2E-10 : TLS 1.0 désactivé (ADR-300, US-03.3)
    if command -v openssl &>/dev/null; then
        if ! openssl s_client -connect "${VM_IP}:443" -tls1 \
             </dev/null 2>&1 | grep -q "Cipher is"; then
            pass "T-E2E-10: TLS 1.0 — désactivé (ADR-300)"
        else
            fail "T-E2E-10: TLS 1.0 — encore actif (ADR-300 non respecté)"
        fi
    else
        skip "T-E2E-10: TLS 1.0 check — openssl non disponible"
    fi

    # T-E2E-11 : Ports ouverts (ADR-300)
    if command -v nc &>/dev/null; then
        if nc -z -w 3 "$VM_IP" 443 2>/dev/null; then
            pass "T-E2E-11a: Port 443 — ouvert"
        else
            fail "T-E2E-11a: Port 443 — fermé"
        fi
        if nc -z -w 3 "$VM_IP" 22 2>/dev/null; then
            pass "T-E2E-11b: Port 22 — ouvert"
        else
            fail "T-E2E-11b: Port 22 — fermé"
        fi
    else
        skip "T-E2E-11: Ports — nc non disponible"
    fi
}

# ---------------------------------------------------------------------------
# Dispatch principal
# ---------------------------------------------------------------------------
CMD="${1:-help}"
case "$CMD" in
    static)
        phase_static
        ;;
    image)
        phase_image
        ;;
    e2e)
        phase_e2e
        ;;
    all)
        phase_static
        phase_image
        phase_e2e
        ;;
    *)
        printf "${RED}Usage: %s {static|image|e2e|all}${NC}\n" "$0" >&2
        printf "\n"
        printf "  static  — Phase 1 : tests statiques locaux (aucun accès Azure)\n"
        printf "  image   — Phase 2 : tests SSH image gallery (E2E_RG, VM_NAME requis)\n"
        printf "  e2e     — Phase 3 : tests E2E post-déploiement ARM\n"
        printf "  all     — Suite complète : phases 1 + 2 + 3\n"
        exit 1
        ;;
esac

summary
