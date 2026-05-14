#!/usr/bin/env bash
# packer/provisioners/03-install-apache.sh
# Installation Apache 2.4 + PHP-FPM socket Unix + VirtualHost HTTPS
# ADR-613 — Architecture et Validation des Provisioners Packer
#
# Variables d'environnement injectées par Packer (smw-vm.pkr.hcl) :
#   PHP_VERSION  — ex: 8.2
#   SMW_LOG_FILE — chemin du fichier de log
#
# ⚠️ Aucune version codée en dur dans ce script.
set -euo pipefail

LOG_FILE="${SMW_LOG_FILE:-/var/log/smw-install.log}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "[03-install-apache] Démarrage — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[03-install-apache] PHP_VERSION=${PHP_VERSION}"
echo "============================================================"

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1. Installation Apache 2.4
# ---------------------------------------------------------------------------
echo "[03-install-apache] Installation d'Apache 2.4..."
apt-get install -y apache2

# ---------------------------------------------------------------------------
# 2. Activation des modules Apache requis
# ---------------------------------------------------------------------------
echo "[03-install-apache] Activation des modules Apache..."
a2enmod rewrite
a2enmod ssl
a2enmod headers
a2enmod proxy_fcgi
a2enmod setenvif
a2enconf "php${PHP_VERSION}-fpm"

# ---------------------------------------------------------------------------
# 3. Certificat TLS auto-signé (provisoire — remplacé par Let's Encrypt ou cert custom)
# ---------------------------------------------------------------------------
echo "[03-install-apache] Génération du certificat TLS auto-signé..."
SSL_DIR="/etc/apache2/ssl"
mkdir -p "${SSL_DIR}"

openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout "${SSL_DIR}/smw.key" \
    -out "${SSL_DIR}/smw.crt" \
    -subj "/C=CA/ST=Quebec/L=Montreal/O=SMW-Marketplace/CN=localhost"

chmod 600 "${SSL_DIR}/smw.key"
chmod 644 "${SSL_DIR}/smw.crt"

# ---------------------------------------------------------------------------
# 4. Configuration VirtualHost : HTTP → HTTPS redirect + VHost HTTPS
# ---------------------------------------------------------------------------
echo "[03-install-apache] Configuration du VirtualHost..."

cat > /etc/apache2/sites-available/smw.conf <<'VHOST'
# VirtualHost HTTP — redirection vers HTTPS
<VirtualHost *:80>
    ServerName localhost
    RewriteEngine On
    RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
</VirtualHost>

# VirtualHost HTTPS — Semantic MediaWiki
<VirtualHost *:443>
    ServerName localhost
    DocumentRoot /opt/mediawiki

    SSLEngine on
    SSLCertificateFile    /etc/apache2/ssl/smw.crt
    SSLCertificateKeyFile /etc/apache2/ssl/smw.key

    # TLS 1.2+ uniquement (ADR-300)
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5

    # En-têtes de sécurité (ADR-300)
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    <Directory /opt/mediawiki>
        Options FollowSymLinks
        AllowOverride All
        Require all granted

        # MediaWiki short URLs — /wiki/$1 → index.php (ADR-613)
        RewriteEngine On
        RewriteRule ^/?wiki(/.*)?$ /index.php [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.php [L]
    </Directory>

    # PHP-FPM via socket Unix
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php${PHP_VERSION}-fpm.sock|fcgi://localhost"
    </FilesMatch>

    ErrorLog  /data/logs/apache-error.log
    CustomLog /data/logs/apache-access.log combined
</VirtualHost>
VHOST

# Remplacer ${PHP_VERSION} dans le fichier de config
sed -i "s/\${PHP_VERSION}/${PHP_VERSION}/g" /etc/apache2/sites-available/smw.conf

# Activer le site SMW, désactiver le site par défaut
a2dissite 000-default.conf || true
a2ensite smw.conf

# ---------------------------------------------------------------------------
# 5. Activation du service Apache
# ---------------------------------------------------------------------------
echo "[03-install-apache] Activation du service apache2..."
systemctl enable apache2

echo "[03-install-apache] Terminé — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"
