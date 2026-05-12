#!/usr/bin/env bash
# packer/provisioners/08-firstboot-setup.sh
# Déploiement du mécanisme de premier démarrage dans l'image Packer
# ADR-613 — Architecture et Validation des Provisioners Packer
# ADR-800 — Publication Offre VM Azure Marketplace
#
# Variables d'environnement injectées par Packer (smw-vm.pkr.hcl) :
#   SMW_LOG_FILE — chemin du fichier de log
#
# Ce provisioner s'exécute lors du BUILD Packer. Il dépose dans l'image :
#   1. /usr/local/bin/smw-firstboot.sh  — script de configuration au premier boot
#   2. /etc/systemd/system/smw-firstboot.service — unit systemd oneshot
#   3. /var/lib/smw/  — répertoire du sentinel d'idempotence (ADR-613, US-02.3)
#   4. /opt/smw-marketplace/firstboot/params.env.example — gabarit pour tests E2E
#
# smw-firstboot.sh s'exécute AU PREMIER DÉMARRAGE de la VM cliente :
#   - Lecture des paramètres ARM via customData (Azure VM Agent)
#   - Configuration MySQL (mot de passe mediawiki@localhost)
#   - Initialisation MediaWiki (maintenance/install.php)
#   - Écriture LocalSettings.firstboot.php (credentials, server, secret key)
#   - Initialisation SMW (maintenance/update.php --quick)
#   - Génération du certificat TLS self-signed
#   - Redémarrage Apache
#   - Création du sentinel /var/lib/smw/.firstboot-done (idempotence)
#
# ⚠️ Aucun secret dans l'image. Les credentials arrivent via ARM customData.
set -euo pipefail

LOG_FILE="${SMW_LOG_FILE:-/var/log/smw-install.log}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "[08-firstboot-setup] Démarrage — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"

# ---------------------------------------------------------------------------
# 1. Répertoires de support firstboot
# ---------------------------------------------------------------------------
echo "[08-firstboot-setup] Création des répertoires firstboot..."
mkdir -p /var/lib/smw
mkdir -p /opt/smw-marketplace/firstboot
chown root:root /var/lib/smw
chmod 700 /var/lib/smw
chown root:root /opt/smw-marketplace/firstboot
chmod 755 /opt/smw-marketplace/firstboot

# ---------------------------------------------------------------------------
# 2. Gabarit de paramètres pour E2E / dev (source : ADR-614)
#    En production, les params arrivent via ARM customData (base64 JSON)
#    Pour E2E, créer /opt/smw-marketplace/firstboot/params.env avec les valeurs
# ---------------------------------------------------------------------------
cat > /opt/smw-marketplace/firstboot/params.env.example << 'ENV_EXAMPLE'
# /opt/smw-marketplace/firstboot/params.env
# Gabarit de configuration pour tests E2E (ADR-614 — dev VM iteration workflow)
# En production, les paramètres arrivent via ARM customData (base64 JSON).
# USAGE : cp params.env.example params.env && éditez les valeurs
#
# Conventions ARM (createUIDefinition.json — US-02.1) :
SMW_WIKI_NAME="SMW Marketplace"
SMW_WIKI_HOSTNAME="localhost"
SMW_ADMIN_USER="WikiAdmin"
SMW_ADMIN_EMAIL="admin@example.com"
SMW_ADMIN_PASSWORD="ChangeMe123!"
SMW_DB_PASSWORD="ChangeMe456!"
ENV_EXAMPLE
chmod 644 /opt/smw-marketplace/firstboot/params.env.example

# ---------------------------------------------------------------------------
# 3. Déploiement de /usr/local/bin/smw-firstboot.sh
#    Ce script s'exécute au premier boot de la VM cliente.
# ---------------------------------------------------------------------------
echo "[08-firstboot-setup] Déploiement de smw-firstboot.sh..."
cat > /usr/local/bin/smw-firstboot.sh << 'FIRSTBOOT_SCRIPT'
#!/usr/bin/env bash
# /usr/local/bin/smw-firstboot.sh
# Configuration automatique au premier démarrage — SMW Marketplace
# Exécuté par smw-firstboot.service (systemd Type=oneshot)
# ADR-613 §Cloud-Init — Configuration au Premier Boot
# ADR-800 — Publication Offre VM Azure Marketplace
# US-02.2 — Wiki accessible en HTTPS dès le premier boot
# US-02.3 — Idempotence (sentinel /var/lib/smw/.firstboot-done)
set -euo pipefail

LOG_FILE="/var/log/smw-firstboot.log"
SENTINEL="/var/lib/smw/.firstboot-done"
MW_DIR="/opt/mediawiki"
FIRSTBOOT_PARAMS="/opt/smw-marketplace/firstboot/params.env"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "[smw-firstboot] Démarrage — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"

# ---------------------------------------------------------------------------
# Idempotence — US-02.3
# ---------------------------------------------------------------------------
if [[ -f "${SENTINEL}" ]]; then
    echo "[smw-firstboot] Sentinel trouvé — firstboot déjà exécuté. Abandon."
    exit 0
fi

# ---------------------------------------------------------------------------
# Lecture des paramètres
# Priorité : 1) ARM customData (Azure VM Agent)
#            2) params.env (E2E/dev — ADR-614)
#            3) valeurs par défaut avec mots de passe générés
# ---------------------------------------------------------------------------
AZURE_CUSTOM_DATA="/var/lib/waagent/CustomData"

if [[ -f "${AZURE_CUSTOM_DATA}" ]]; then
    echo "[smw-firstboot] Lecture des paramètres depuis ARM customData..."
    CUSTOM_JSON=$(base64 -d "${AZURE_CUSTOM_DATA}" 2>/dev/null || cat "${AZURE_CUSTOM_DATA}")
    SMW_WIKI_NAME=$(echo "${CUSTOM_JSON}"     | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('wikiName','SMW Marketplace'))"      2>/dev/null || echo "SMW Marketplace")
    SMW_WIKI_HOSTNAME=$(echo "${CUSTOM_JSON}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('wikiHostName','localhost'))"          2>/dev/null || echo "localhost")
    SMW_ADMIN_USER=$(echo "${CUSTOM_JSON}"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('wikiAdminUser','WikiAdmin'))"          2>/dev/null || echo "WikiAdmin")
    SMW_ADMIN_EMAIL=$(echo "${CUSTOM_JSON}"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('wikiAdminEmail','admin@example.com'))" 2>/dev/null || echo "admin@example.com")
    SMW_ADMIN_PASSWORD=$(echo "${CUSTOM_JSON}"| python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('wikiAdminPassword',''))"              2>/dev/null || echo "")
    SMW_DB_PASSWORD=$(echo "${CUSTOM_JSON}"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('databasePassword',''))"               2>/dev/null || echo "")
    echo "[smw-firstboot] Source : ARM customData"

elif [[ -f "${FIRSTBOOT_PARAMS}" ]]; then
    echo "[smw-firstboot] Lecture des paramètres depuis ${FIRSTBOOT_PARAMS}..."
    # shellcheck disable=SC1090
    source "${FIRSTBOOT_PARAMS}"
    echo "[smw-firstboot] Source : params.env (mode E2E/dev)"

else
    echo "[smw-firstboot] AVERTISSEMENT: aucune source de paramètres — génération automatique"
    SMW_WIKI_NAME="SMW Marketplace"
    SMW_WIKI_HOSTNAME="localhost"
    SMW_ADMIN_USER="WikiAdmin"
    SMW_ADMIN_EMAIL="admin@example.com"
    SMW_ADMIN_PASSWORD=""
    SMW_DB_PASSWORD=""
fi

# Valider / générer les mots de passe si absents
if [[ -z "${SMW_ADMIN_PASSWORD:-}" ]]; then
    SMW_ADMIN_PASSWORD="$(openssl rand -base64 18 | tr -d '/+' | head -c 20)Aa1!"
    echo "[smw-firstboot] Mot de passe admin généré automatiquement"
fi
if [[ -z "${SMW_DB_PASSWORD:-}" ]]; then
    SMW_DB_PASSWORD="$(openssl rand -base64 18 | tr -d '/+' | head -c 20)"
    echo "[smw-firstboot] Mot de passe DB généré automatiquement"
fi

WIKI_SERVER="https://${SMW_WIKI_HOSTNAME}"
echo "[smw-firstboot] Paramètres : wiki=${SMW_WIKI_NAME} | hostname=${SMW_WIKI_HOSTNAME} | admin=${SMW_ADMIN_USER}"

# ---------------------------------------------------------------------------
# 1. Configuration MySQL — définir le mot de passe de mediawiki@localhost
# ---------------------------------------------------------------------------
echo "[smw-firstboot] Configuration MySQL mediawiki@localhost..."

# Démarrer MySQL si pas actif (edge case : service arrêté)
if ! mysqladmin ping --silent 2>/dev/null; then
    echo "[smw-firstboot] Démarrage MySQL..."
    systemctl start mysql
    for i in $(seq 1 30); do
        mysqladmin ping --silent 2>/dev/null && break || sleep 2
    done
fi

mysql --user=root << SQL
ALTER USER 'mediawiki'@'localhost' IDENTIFIED BY '${SMW_DB_PASSWORD}';
FLUSH PRIVILEGES;
SQL
echo "[smw-firstboot] ✓ Mot de passe MySQL mediawiki@localhost configuré"

# ---------------------------------------------------------------------------
# 2. Initialisation MediaWiki (maintenance/install.php)
#    install.php refuse de tourner si LocalSettings.php existe → on le déplace
# ---------------------------------------------------------------------------
echo "[smw-firstboot] Initialisation MediaWiki (maintenance/install.php)..."
cd "${MW_DIR}"

# Sauvegarder le skeleton LocalSettings.php (déployé par 06-install-smw.sh)
if [[ -f "${MW_DIR}/LocalSettings.php" ]]; then
    mv "${MW_DIR}/LocalSettings.php" "${MW_DIR}/LocalSettings.skeleton.php"
    echo "[smw-firstboot] LocalSettings.php skeleton sauvegardé"
fi

# Exécuter install.php — génère LocalSettings.php + initialise le schéma DB
sudo -u www-data php "${MW_DIR}/maintenance/install.php" \
    --dbserver   "localhost" \
    --dbname     "mediawiki" \
    --dbuser     "mediawiki" \
    --dbpass     "${SMW_DB_PASSWORD}" \
    --server     "${WIKI_SERVER}" \
    --scriptpath "" \
    --lang       "en" \
    --pass       "${SMW_ADMIN_PASSWORD}" \
    "${SMW_WIKI_NAME}" \
    "${SMW_ADMIN_USER}"

echo "[smw-firstboot] ✓ MediaWiki installé (schéma DB + utilisateur admin créé)"

# Extraire les clés générées par install.php (supporte guillemets simples ET doubles)
WG_SECRET_KEY=$(grep '^\$wgSecretKey' "${MW_DIR}/LocalSettings.php" | head -1 | sed "s/.*= [\"']\\([^\"']*\\)[\"'].*/\\1/")
[[ -z "${WG_SECRET_KEY}" ]] && WG_SECRET_KEY=$(openssl rand -hex 32)
WG_UPGRADE_KEY=$(grep '^\$wgUpgradeKey' "${MW_DIR}/LocalSettings.php" | head -1 | sed "s/.*= [\"']\\([^\"']*\\)[\"'].*/\\1/")
[[ -z "${WG_UPGRADE_KEY}" ]] && WG_UPGRADE_KEY=$(openssl rand -hex 16)

# Supprimer le LocalSettings.php généré par install.php
rm -f "${MW_DIR}/LocalSettings.php"

# Restaurer le skeleton
if [[ -f "${MW_DIR}/LocalSettings.skeleton.php" ]]; then
    mv "${MW_DIR}/LocalSettings.skeleton.php" "${MW_DIR}/LocalSettings.php"
    echo "[smw-firstboot] LocalSettings.php skeleton restauré"
fi

# ---------------------------------------------------------------------------
# 3. Écriture de LocalSettings.firstboot.php
#    Inclus par le skeleton LocalSettings.php (file_exists guard)
# ---------------------------------------------------------------------------
echo "[smw-firstboot] Écriture de LocalSettings.firstboot.php..."
cat > "${MW_DIR}/LocalSettings.firstboot.php" << PHP
<?php
# LocalSettings.firstboot.php — Généré au premier démarrage par smw-firstboot.service
# NE PAS MODIFIER MANUELLEMENT — ce fichier est géré par le mécanisme firstboot.
# ADR-613, ADR-800

\$wgSitename   = "${SMW_WIKI_NAME}";
\$wgServer     = "${WIKI_SERVER}";
\$wgScriptPath = "";
\$wgArticlePath = "/wiki/\$1";

\$wgDBserver   = "localhost";
\$wgDBname     = "mediawiki";
\$wgDBuser     = "mediawiki";
\$wgDBpassword = "${SMW_DB_PASSWORD}";
\$wgDBtype     = "mysql";

\$wgSecretKey  = "${WG_SECRET_KEY}";
\$wgUpgradeKey = "${WG_UPGRADE_KEY}";

\$wgEmergencyContact = "${SMW_ADMIN_EMAIL}";
\$wgPasswordSender   = "${SMW_ADMIN_EMAIL}";

# Upload path
\$wgUploadDirectory = "/data/uploads";
\$wgUploadPath      = "/wiki/images";

# Cache MediaWiki
\$wgMainCacheType = CACHE_ACCEL;
\$wgMemCachedServers = [];
PHP

chown www-data:www-data "${MW_DIR}/LocalSettings.firstboot.php"
chmod 640 "${MW_DIR}/LocalSettings.firstboot.php"
echo "[smw-firstboot] ✓ LocalSettings.firstboot.php créé"

# ---------------------------------------------------------------------------
# 4. Initialisation SMW (maintenance/update.php)
#    Ajoute les tables SMW au schéma MediaWiki existant
# ---------------------------------------------------------------------------
echo "[smw-firstboot] Initialisation SMW (maintenance/update.php)..."
cd "${MW_DIR}"
sudo -u www-data php maintenance/update.php --quick 2>&1 | tail -20
echo "[smw-firstboot] ✓ Tables SMW initialisées"

# ---------------------------------------------------------------------------
# 5. Génération du certificat TLS self-signed (US-02.2)
# ---------------------------------------------------------------------------
echo "[smw-firstboot] Génération du certificat TLS self-signed..."
mkdir -p /etc/apache2/ssl

VM_IP="$(hostname -I | awk '{print $1}')"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/apache2/ssl/smw-selfsigned.key \
    -out    /etc/apache2/ssl/smw-selfsigned.crt \
    -subj   "/C=CA/ST=Quebec/L=Montreal/O=SMW Marketplace/CN=${SMW_WIKI_HOSTNAME}" \
    -addext "subjectAltName=DNS:${SMW_WIKI_HOSTNAME},IP:${VM_IP}" \
    2>&1

chmod 600 /etc/apache2/ssl/smw-selfsigned.key
chmod 644 /etc/apache2/ssl/smw-selfsigned.crt
echo "[smw-firstboot] ✓ Certificat TLS généré pour CN=${SMW_WIKI_HOSTNAME}"

# Mettre à jour les VirtualHost Apache pour pointer sur le nouveau certificat
for conf_file in /etc/apache2/sites-available/*.conf; do
    sed -i "s|SSLCertificateFile .*|SSLCertificateFile /etc/apache2/ssl/smw-selfsigned.crt|" "${conf_file}" 2>/dev/null || true
    sed -i "s|SSLCertificateKeyFile .*|SSLCertificateKeyFile /etc/apache2/ssl/smw-selfsigned.key|" "${conf_file}" 2>/dev/null || true
done

# ---------------------------------------------------------------------------
# 6. Redémarrage Apache
# ---------------------------------------------------------------------------
echo "[smw-firstboot] Redémarrage Apache..."
systemctl restart apache2
echo "[smw-firstboot] ✓ Apache redémarré"

# ---------------------------------------------------------------------------
# Sentinel — marquer le firstboot comme terminé (idempotence US-02.3)
# Créé UNIQUEMENT en cas de succès complet
# ---------------------------------------------------------------------------
touch "${SENTINEL}"
chmod 400 "${SENTINEL}"

echo "============================================================"
echo "[smw-firstboot] Terminé avec succès — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[smw-firstboot] Wiki accessible : ${WIKI_SERVER}"
echo "============================================================"
FIRSTBOOT_SCRIPT

chmod 700 /usr/local/bin/smw-firstboot.sh
echo "[08-firstboot-setup] ✓ /usr/local/bin/smw-firstboot.sh déployé"

# ---------------------------------------------------------------------------
# 4. Création du service systemd smw-firstboot.service
# ---------------------------------------------------------------------------
echo "[08-firstboot-setup] Création de smw-firstboot.service..."
cat > /etc/systemd/system/smw-firstboot.service << 'SYSTEMD_UNIT'
[Unit]
Description=SMW Marketplace — Configuration au premier démarrage
Documentation=https://github.com/michel-heon/semantic-media-wiki-marketplace
After=network-online.target mysql.service apache2.service
Wants=network-online.target
# Ne s'exécute que si le sentinel est absent (idempotence)
ConditionPathExists=!/var/lib/smw/.firstboot-done

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/smw-firstboot.sh
TimeoutStartSec=600
StandardOutput=journal+console
StandardError=journal+console
SyslogIdentifier=smw-firstboot

[Install]
WantedBy=multi-user.target
SYSTEMD_UNIT

chmod 644 /etc/systemd/system/smw-firstboot.service
echo "[08-firstboot-setup] ✓ smw-firstboot.service créé"

# ---------------------------------------------------------------------------
# 5. Activation du service (démarrera au premier boot du client)
# ---------------------------------------------------------------------------
echo "[08-firstboot-setup] Activation de smw-firstboot.service..."
systemctl daemon-reload
systemctl enable smw-firstboot.service
echo "[08-firstboot-setup] ✓ smw-firstboot.service activé (WantedBy multi-user.target)"

echo "[08-firstboot-setup] Terminé — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"
