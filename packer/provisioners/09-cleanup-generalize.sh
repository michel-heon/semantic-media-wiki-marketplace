#!/usr/bin/env bash
# packer/provisioners/09-cleanup-generalize.sh
# Nettoyage et généralisation de la VM avant capture (waagent deprovision)
# ADR-613 — Architecture et Validation des Provisioners Packer
# ADR-617 — Packer : outil de construction d'images VM Azure Marketplace
#
# Variables d'environnement injectées par Packer (smw-vm.pkr.hcl) :
#   SMW_LOG_FILE — chemin du fichier de log
#
# ⚠️ Ce script DOIT être le dernier provisioner exécuté.
# ⚠️ La dernière commande DOIT être : waagent -force -deprovision+user
# ⚠️ NE PAS ajouter de commandes après waagent.
set -euo pipefail

LOG_FILE="${SMW_LOG_FILE:-/var/log/smw-install.log}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "[09-cleanup-generalize] Démarrage — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"

# ---------------------------------------------------------------------------
# 1. Nettoyage des credentials et informations sensibles temporaires
# ---------------------------------------------------------------------------
echo "[09-cleanup-generalize] Nettoyage des credentials temporaires..."

# Variables d'environnement potentiellement sensibles — purge du fichier /etc/environment
# (les variables Packer sont dans l'environnement du processus, pas dans /etc/environment,
#  mais on s'assure qu'aucune clé n'a été écrite)
if [[ -f /etc/environment ]]; then
    # Supprimer toute ligne qui contiendrait des tokens ou secrets
    sed -i '/ARM_CLIENT_SECRET\|ARM_CLIENT_ID\|PACKER_SAS_TOKEN\|AZURE_/d' /etc/environment || true
fi

# ---------------------------------------------------------------------------
# 2. Nettoyage des logs système et logs d'installation
# ---------------------------------------------------------------------------
echo "[09-cleanup-generalize] Nettoyage des logs..."

# Vider les logs APT
find /var/log/apt -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true

# Vider les logs système (seront réinitialisés au 1er boot)
for log_file in /var/log/syslog /var/log/kern.log /var/log/auth.log \
                /var/log/messages /var/log/cloud-init.log \
                /var/log/cloud-init-output.log; do
    [[ -f "${log_file}" ]] && truncate -s 0 "${log_file}" || true
done

# Purger journald
journalctl --rotate --vacuum-time=1s 2>/dev/null || true

# ---------------------------------------------------------------------------
# 3. Nettoyage du cache APT et des packages inutiles
# ---------------------------------------------------------------------------
echo "[09-cleanup-generalize] Nettoyage APT..."
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 4. Nettoyage des historiques bash et SSH known_hosts + authorized_keys (T4)
#    Politique Microsoft Marketplace 200.5 — clés SSH de build supprimées.
# ---------------------------------------------------------------------------
echo "[09-cleanup-generalize] Nettoyage des historiques utilisateurs..."

# root
truncate -s 0 /root/.bash_history 2>/dev/null || true
rm -f /root/.ssh/known_hosts 2>/dev/null || true
rm -f /root/.ssh/authorized_keys 2>/dev/null || true

# ubuntu (utilisateur par défaut Azure Marketplace) + tout user supplémentaire
for user_home in /home/*; do
    if [[ -d "${user_home}" ]]; then
        truncate -s 0 "${user_home}/.bash_history" 2>/dev/null || true
        rm -f "${user_home}/.ssh/known_hosts" 2>/dev/null || true
        rm -f "${user_home}/.ssh/authorized_keys" 2>/dev/null || true
    fi
done

echo "[09-cleanup-generalize] [T4] Validation suppression authorized_keys..."
if find /root/.ssh /home/*/.ssh -name authorized_keys 2>/dev/null | grep -q .; then
    echo "[09-cleanup-generalize] ❌ ERREUR : authorized_keys résiduels détectés" >&2
    find /root/.ssh /home/*/.ssh -name authorized_keys 2>/dev/null >&2
    exit 1
fi
echo "[09-cleanup-generalize] [T4] ✅ Aucun authorized_keys résiduel"

# ---------------------------------------------------------------------------
# 4.b Désactivation du swap sur disque OS (T3 — Politique 200.3.3)
#     Azure exige aucune partition swap sur le disque OS.
#     Swap géré ultérieurement via le resource disk éphémère par cloud-init.
# ---------------------------------------------------------------------------
echo "[09-cleanup-generalize] [T3] Désactivation du swap OS disk..."
swapoff -a || true
# Retire toutes les entrées swap du fstab (commentées ou non)
sed -i.bak '/\sswap\s/d' /etc/fstab
# Validation
if grep -E '^[^#].*\sswap\s' /etc/fstab; then
    echo "[09-cleanup-generalize] ❌ ERREUR : entrée swap résiduelle dans /etc/fstab" >&2
    exit 1
fi
if swapon --show 2>/dev/null | grep -q .; then
    echo "[09-cleanup-generalize] ❌ ERREUR : swap actif après swapoff" >&2
    swapon --show >&2
    exit 1
fi
echo "[09-cleanup-generalize] [T3] ✅ Swap désactivé et purgé de /etc/fstab"
# Supprimer le backup généré par sed (sinon il reste dans l'image)
rm -f /etc/fstab.bak

# ---------------------------------------------------------------------------
# 4.c Audit des cron jobs et journaux sensibles (T7 — Politique 200.5)
#     Inventaire de tout cron non-OS et garantie d'absence de credentials
#     dans les logs applicatifs résiduels (LocalSettings.php, etc.).
# ---------------------------------------------------------------------------
echo "[09-cleanup-generalize] [T7] Audit des cron jobs..."

# Inventaire — pour traçabilité (visible dans log Packer)
echo "  → /etc/crontab :"
[ -f /etc/crontab ] && grep -vE '^(#|$)' /etc/crontab || echo "  (vide ou absent)"

echo "  → /etc/cron.d/ :"
if [ -d /etc/cron.d ]; then
    for _f in /etc/cron.d/*; do
        [ -f "${_f}" ] && echo "    $(basename "${_f}"): $(grep -vEc '^(#|$)' "${_f}" || echo 0) entrées actives"
    done
fi

echo "  → /etc/cron.{hourly,daily,weekly,monthly}/ :"
for _period in hourly daily weekly monthly; do
    _dir="/etc/cron.${_period}"
    if [ -d "${_dir}" ]; then
        _files=$(find "${_dir}" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l)
        echo "    ${_period}: ${_files} script(s)"
    fi
done

echo "  → crontabs utilisateurs (/var/spool/cron/crontabs/) :"
if [ -d /var/spool/cron/crontabs ]; then
    _user_crons=$(find /var/spool/cron/crontabs -maxdepth 1 -type f 2>/dev/null | wc -l)
    echo "    ${_user_crons} crontab utilisateur(s)"
fi

echo "  → systemd timers actifs :"
systemctl list-timers --no-pager --no-legend 2>/dev/null \
    | awk '{print "    " $NF}' | head -20 || echo "    (aucun)"

# Politique : aucun cron applicatif SMW/MediaWiki ne doit avoir été ajouté
# sans documentation. On vérifie l'absence de crontabs utilisateurs créés
# par les provisioners (root/www-data en particulier).
echo "[09-cleanup-generalize] [T7] Validation absence de crontabs applicatifs non-documentés..."
for _user in www-data mysql apache; do
    if [ -f "/var/spool/cron/crontabs/${_user}" ]; then
        echo "[09-cleanup-generalize] ⚠ AVERTISSEMENT : crontab ${_user} détecté — vérifier intention" >&2
        cat "/var/spool/cron/crontabs/${_user}" >&2
    fi
done

# Garantir absence de credentials clairs dans les logs résiduels avant capture.
# (Les logs ont été vidés en section 2, mais on vérifie qu'aucun nouveau log
#  écrit ensuite ne contienne de pattern sensible.)
echo "[09-cleanup-generalize] [T7] Scan logs résiduels pour credentials clairs..."
_susp=0
for _log in /var/log/syslog /var/log/auth.log /var/log/cloud-init-output.log \
            /var/log/smw-install.log; do
    if [ -s "${_log}" ] 2>/dev/null; then
        # Patterns à risque : mot de passe ou clé privée en clair
        if grep -aEi 'password[[:space:]]*=[[:space:]]*[^"$ ]+|BEGIN (RSA|OPENSSH) PRIVATE KEY' \
               "${_log}" 2>/dev/null | grep -v '^#' | head -3; then
            echo "[09-cleanup-generalize] ⚠ Pattern sensible détecté dans ${_log}" >&2
            _susp=$((_susp + 1))
        fi
    fi
done
if [ "${_susp}" -gt 0 ]; then
    echo "[09-cleanup-generalize] ❌ ERREUR : ${_susp} log(s) contiennent possiblement des credentials" >&2
    exit 1
fi
echo "[09-cleanup-generalize] [T7] ✅ Aucun credential clair dans les logs résiduels"

# ---------------------------------------------------------------------------
# 5. Nettoyage des fichiers temporaires de build
# ---------------------------------------------------------------------------
echo "[09-cleanup-generalize] Nettoyage des fichiers temporaires..."
rm -rf /tmp/* 2>/dev/null || true
rm -rf /var/tmp/* 2>/dev/null || true

# Supprimer les archives de déploiement si laissées sur disque
find /tmp -maxdepth 1 -name "*.tar.gz" -delete 2>/dev/null || true
find /tmp -maxdepth 1 -name "*.zip" -delete 2>/dev/null || true

# ---------------------------------------------------------------------------
# 6. Synchronisation des disques avant déprovision
# ---------------------------------------------------------------------------
echo "[09-cleanup-generalize] Synchronisation disque..."
sync

# ---------------------------------------------------------------------------
# 7. Généralisation de la VM avec waagent
#    ⚠️ DOIT être la DERNIÈRE commande exécutée (ADR-617)
#    ⚠️ Aucune commande après cette ligne ne sera exécutée
# ---------------------------------------------------------------------------
echo "[09-cleanup-generalize] Généralisation waagent — DERNIÈRE ÉTAPE"
/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync
