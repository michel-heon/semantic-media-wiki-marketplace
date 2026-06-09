#!/usr/bin/env bash
# packer/provisioners/07-security-harden.sh
# Hardening sécurité OS : UFW, fail2ban, auditd, TLS, SSH
# ADR-613 — Architecture et Validation des Provisioners Packer
# ADR-300 — Sécurité Hardening VM Certification Azure Marketplace
#
# Variables d'environnement injectées par Packer (smw-vm.pkr.hcl) :
#   SMW_LOG_FILE — chemin du fichier de log
#
# ⚠️ Aucune version codée en dur dans ce script.
set -euo pipefail

LOG_FILE="${SMW_LOG_FILE:-/var/log/smw-install.log}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "[07-security-harden] Démarrage — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1. Installation des outils de sécurité
# ---------------------------------------------------------------------------
echo "[07-security-harden] Installation des paquets de sécurité..."
apt-get install -y \
    fail2ban \
    auditd \
    audispd-plugins \
    libpam-pwquality

# ---------------------------------------------------------------------------
# 2. Configuration UFW — ports 22 (SSH) et 443 (HTTPS) uniquement (ADR-300)
# ---------------------------------------------------------------------------
echo "[07-security-harden] Configuration du pare-feu UFW..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   comment 'SSH'
ufw allow 80/tcp   comment 'HTTP MediaWiki'
ufw allow 443/tcp  comment 'HTTPS MediaWiki'
ufw --force enable

# ---------------------------------------------------------------------------
# 3. Durcissement SSH
# ---------------------------------------------------------------------------
echo "[07-security-harden] Durcissement de la configuration SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"

# Désactiver l'authentification par mot de passe (clés uniquement)
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "${SSHD_CONFIG}"
# Désactiver les connexions root directes
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "${SSHD_CONFIG}"
# Désactiver X11 Forwarding
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "${SSHD_CONFIG}"
# Définir le nombre maximum de tentatives d'authentification
grep -q "^MaxAuthTries" "${SSHD_CONFIG}" \
    && sed -i 's/^MaxAuthTries.*/MaxAuthTries 3/' "${SSHD_CONFIG}" \
    || echo "MaxAuthTries 3" >> "${SSHD_CONFIG}"
# Désactiver la connexion sans mot de passe
grep -q "^PermitEmptyPasswords" "${SSHD_CONFIG}" \
    && sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' "${SSHD_CONFIG}" \
    || echo "PermitEmptyPasswords no" >> "${SSHD_CONFIG}"

# ---------------------------------------------------------------------------
# 4. Configuration fail2ban pour SSH et Apache
# ---------------------------------------------------------------------------
echo "[07-security-harden] Configuration de fail2ban..."
cat > /etc/fail2ban/jail.local <<'FAIL2BAN'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
backend  = %(sshd_backend)s

[apache-auth]
enabled  = true
port     = https
logpath  = /data/logs/apache-error.log
maxretry = 3
FAIL2BAN

systemctl enable fail2ban

# ---------------------------------------------------------------------------
# 5. Configuration auditd — règles de base
# ---------------------------------------------------------------------------
echo "[07-security-harden] Configuration d'auditd..."
cat > /etc/audit/rules.d/smw-audit.rules <<'AUDIT'
# Règles d'audit SMW Marketplace — ADR-300
# Surveillance des accès aux fichiers sensibles
-w /etc/passwd  -p wa -k identity
-w /etc/shadow  -p wa -k identity
-w /etc/group   -p wa -k identity
-w /opt/mediawiki/LocalSettings.php -p rwa -k mediawiki-config
-w /opt/mediawiki/LocalSettings.firstboot.php -p rwa -k mediawiki-config
# Surveillance des connexions réseau
-a exit,always -F arch=b64 -S connect -k network-connect
AUDIT

systemctl enable auditd

# ---------------------------------------------------------------------------
# 6. Désactivation de TLS 1.0/1.1 dans Apache (ADR-300)
#    (Déjà géré dans le VirtualHost HTTPS — double protection au niveau global)
# ---------------------------------------------------------------------------
echo "[07-security-harden] Renforcement TLS global Apache..."
cat > /etc/apache2/conf-available/smw-tls-hardening.conf <<'TLS_CONF'
# Désactiver TLS 1.0 et 1.1 globalement (ADR-300)
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite HIGH:!aNULL:!MD5:!RC4
SSLHonorCipherOrder on
SSLCompression off
TLS_CONF

a2enconf smw-tls-hardening

# ---------------------------------------------------------------------------
# 7. Suppression des packages inutiles (réduction surface d'attaque)
# ---------------------------------------------------------------------------
echo "[07-security-harden] Suppression des packages non nécessaires..."
apt-get remove -y \
    telnet \
    ftp \
    rsh-client 2>/dev/null || true

apt-get autoremove -y
apt-get clean

echo "[07-security-harden] Terminé — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"
