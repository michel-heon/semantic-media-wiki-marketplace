---
adr: 300
title: "Sécurité VM — Hardening OS Ubuntu pour Certification Azure Marketplace"
status: "accepted"
date: 2026-02-22
superseded_by: null
replaces: null
related_adrs: [200, 619, 700, 800, 804]
related_issues: [4, 29]

classification:
  lifecycle: "accepted"
  domain: "security"
  impact: "critical"
  quality:
    - "security"
    - "compliance"
    - "reliability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "azure"
    - "tls"
    - "nsg"
    - "mediawiki"
    - "apache"

tags: ["security", "hardening", "tls", "ssh", "ufw", "certification", "azure-marketplace", "ubuntu"]
stakeholders: ["@devops-team", "@architecture-team"]
effort: "medium"
---

# ADR-300 : Sécurité VM — Hardening OS pour Certification Azure Marketplace

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-02-22 |
| **Impact** | 🔴 Critique (tests de certification automatisés Microsoft) |
| **Risque technique** | 🔴 Élevé (rejet certification si non conforme) |
| **Portée** | Tactique — provisioner `security-harden.sh` |

---

## 🎯 Contexte

Microsoft exécute le **AMAT (Azure Marketplace Certification Tool)** sur chaque image soumise. Les échecs les plus fréquents concernent la sécurité OS. Ce document centralise les 15 contrôles critiques et les décisions prises pour y répondre.

**Source** : [Azure VM certification test cases](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-certification-faq)

---

## 💡 Décisions de Sécurité

### 1. SSH — Authentification par Clé Uniquement

```bash
# /etc/ssh/sshd_config.d/99-marketplace-hardening.conf
PasswordAuthentication no
PermitRootLogin no
ChallengeResponseAuthentication no
ClientAliveInterval 180
ClientAliveCountMax 3
MaxAuthTries 3
AllowTcpForwarding no
X11Forwarding no
```

**Test Microsoft** : vérifie que `PasswordAuthentication` est `no`.

### 2. TLS — Nginx

Déjà implémenté dans `docker/nginx/server.conf` (ADR-606) :
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers   ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...;
```

**Test Microsoft** : vérifie le rejet de TLS 1.1 et inférieur.

### 3. Firewall UFW

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 443/tcp    # HTTPS — MediaWiki
ufw allow 80/tcp     # HTTP → redirect HTTPS
ufw allow 22/tcp     # SSH (restreint par NSG côté Azure — voir ADR-200)
ufw deny  3306/tcp   # MySQL — jamais exposé publiquement
ufw deny  9000/tcp   # PHP-FPM — jamais exposé publiquement
ufw --force enable
```

### 4. Isolation Réseau MySQL et PHP-FPM

Les services MySQL et PHP-FPM n'écoutent que sur loopback. Configuré dans les unit files systemd :

```ini
# /etc/systemd/system/mysql.service (bind-address)
[Service]
bind-address = 127.0.0.1  # dans /etc/mysql/mysql.conf.d/mysqld.cnf
```

```ini
# /etc/systemd/system/php8.2-fpm.service
[Service]
Environment=CATALINA_OPTS=-Djava.net.preferIPv4Stack=true
# server.xml : Connector address="127.0.0.1"
```

### 5. Pas de Credentials par Défaut

- Aucun mot de passe hardcodé dans l'image
- Le mot de passe MySQL est injecté par `cloud-init` depuis les paramètres ARM (`mysqlPassword`)
- Le mot de passe root est désactivé

```bash
# Dans packer provisioner : désactiver root password
sudo passwd -l root
```

### 6. Permissions Fichiers Sensibles

```bash
chmod 600 /etc/nginx/ssl/server.key
chmod 644 /etc/nginx/ssl/server.crt
chown root:root /etc/nginx/ssl/server.key
chmod 750 /data/server/home
chown -R www-data:www-data /opt/mediawiki/ /data/uploads/
```

### 7. Nettoyage Avant Généralisation

Exécuté en **dernier provisioner Packer** (voir ADR-700) :

```bash
# packer/provisioners/generalize.sh
# Vider l'historique shell
history -c && cat /dev/null > ~/.bash_history

# Supprimer logs et fichiers temporaires
find /tmp -type f -delete
find /var/log -type f -exec truncate -s 0 {} \;

# Supprimer les SSH host keys (régénérées au prochain boot)
rm -f /etc/ssh/ssh_host_*

# Supprimer les clés autorisées du build
rm -f /home/*/.ssh/authorized_keys

# Généralisation Azure — TOUJOURS DERNIER
sudo waagent -deprovision+user -force
```

**Test Microsoft** : vérifie que `~/.bash_history` est vide après généralisation.

### 8. Mise à Jour OS Avant Généralisation

Utilisation de `dist-upgrade` (au lieu de `upgrade`) pour capter les transitions de dépendances entre paquets (ex. : `libgnutls30`, `libarchive13`, `bind9-*`, `libwbclient0`). Implémenté dans `packer/provisioners/01-install-base.sh` §1 :

```bash
apt-get update -y
APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
apt-get upgrade "${APT_OPTS[@]}"
apt-get dist-upgrade "${APT_OPTS[@]}"
apt-get autoremove -y && apt-get autoclean -y
```

### 9. Vérification déterministe — Test #16 Patches CVE (rapports 2026-06-02 / 2026-06-13)

Un **gate bloquant** (`return 1` propagé par `set -euo pipefail`) dans
`packer/provisioners/01-install-base.sh` §2.b vérifie, après `dist-upgrade`,
que chaque paquet exposé par la certification AMAT 200.5.8 (rapport Partner
Center du `2026-06-13` sur le plan `standard/6.0.20260517`) est à la version
minimale requise :

| Paquet            | Version requise (USN)              | USN                                                       |
|-------------------|------------------------------------|-----------------------------------------------------------|
| `libgnutls30`     | ≥ `3.7.3-4ubuntu1.9`               | [USN-8284-1](https://ubuntu.com/security/notices/USN-8284-1) |
| `libarchive13`    | ≥ `3.6.0-1ubuntu1.7`               | [USN-8292-1](https://ubuntu.com/security/notices/USN-8292-1) |
| `bind9-host`, `bind9-dnsutils`, `bind9-libs` | ≥ `1:9.18.39-0ubuntu0.22.04.4` | [USN-8293-1](https://ubuntu.com/security/notices/USN-8293-1) |
| `libwbclient0`    | ≥ `2:4.15.13+dfsg-0ubuntu1.12`     | [USN-8306-1](https://ubuntu.com/security/notices/USN-8306-1) |

Si un paquet est sous la version requise, le build Packer **échoue** (la
fonction `check_pkg_min_version` retourne `1`, `set -e` interrompt le
provisioner) et la version installée est tracée dans le log de l'image
(`/var/log/smw-install.log`, purgé par `09-cleanup-generalize.sh`).

> **Note** : le gate s'exécute **avant** la généralisation, donc une image
> qui passerait toutes les étapes mais échouerait sur Test #16 ne pourrait
> **pas** être publiée — par construction.

---

## ✅ Checklist 16 Tests Certification Microsoft

| # | Test | Décision | Provisioner |
|---|------|----------|-------------|
| 1 | `waagent` installé et démarré | ✅ | `waagent-cloud-init.sh` |
| 2 | SSH root désactivé | ✅ | `security-harden.sh` |
| 3 | `PasswordAuthentication no` | ✅ | `security-harden.sh` |
| 4 | Pas de compte user avec mot de passe vide | ✅ | `generalize.sh` |
| 5 | `bash_history` vide après déprovision | ✅ | `generalize.sh` |
| 6 | `/tmp` vide après généralisation | ✅ | `generalize.sh` |
| 7 | SSH host keys absentes | ✅ | `generalize.sh` |
| 8 | TLS 1.1 rejeté | ✅ | `configure-nginx.sh` |
| 9 | TLS 1.2 accepté | ✅ | `configure-nginx.sh` |
| 10 | Port 8983 non exposé publiquement | ✅ | `security-harden.sh` + NSG |
| 11 | OS disk < 2 048 GB | ✅ | Packer config |
| 12 | 2 048 premiers secteurs libres | ✅ | Image Ubuntu endorsée |
| 13 | Mise à jour OS récente (`dist-upgrade`) | ✅ | `01-install-base.sh` |
| 14 | `cloud-init` opérationnel | ✅ | `waagent-cloud-init.sh` |
| 15 | Extensions Azure acceptées (`allowExtensionOperations`) | ✅ | `waagent-cloud-init.sh` |
| 16 | Patches CVE Ubuntu — paquets ≥ versions USN (200.5.8 — rapport 2026-06-13) | ✅ | `01-install-base.sh` (gate bloquant §2.b) |

---

## 📁 Structure Provisioners Packer

```
packer/provisioners/
  01-install-base.sh          ← curl, wget, ufw, dist-upgrade, gate USN, waagent
  02-install-php.sh           ← PHP 8.2-fpm + extensions MediaWiki
  03-install-apache.sh        ← Apache 2.4 + mod_proxy_fcgi
  04-install-mysql.sh         ← MySQL 8.x + base de données wiki
  05-install-mediawiki.sh     ← MediaWiki 1.43.x + configuration
  06-install-smw.sh           ← Semantic MediaWiki 6.0.1 + extensions SSO
  07-security-harden.sh       ← UFW + SSH + fail2ban + auditd + TLS Apache
  08-firstboot-setup.sh       ← service systemd smw-firstboot.service
  09-cleanup-generalize.sh    ← cleanup + waagent -deprovision+user  ← TOUJOURS DERNIER
```

---

## 🔁 Suivi des écarts VM live ↔ Packer

Toute correction de hardening appliquée à chaud sur une VM live (sans passer
par Packer), ou tout écart constaté entre une image gallery publiée et le
code Packer du repo, **DOIT** être consignée dans `docs/vm-live-drift/REGISTRY.md`
afin d'être propagée dans le code Packer et d'éviter qu'une nouvelle image
réintroduise le problème — ou qu'un plan vulnérable continue d'être publié
alors que le fix est déjà committé.

- Voir [`docs/vm-live-drift/README.md`](../vm-live-drift/README.md) — procédure
- Voir [`docs/vm-live-drift/REGISTRY.md`](../vm-live-drift/REGISTRY.md) — tableau des drifts actifs
- Voir [ADR-619](./619-DEVOPS-registre-drift-vm-live-vs-packer.md) — décision fondatrice

Drifts hardening en cours :

- [DRIFT-000](../vm-live-drift/DRIFT-000-cve-patches-ubuntu-200.5.8.md) — patches CVE Ubuntu (USN-8284 / 8292 / 8293 / 8306) sur plan `standard/6.0.20260517` (rapport Partner Center 2026-06-13)

---

## 📎 Références

- ADR-200 : Infrastructure Azure (NSG complémentaire à UFW)
- ADR-619 : Registre des drifts VM Live ↔ Packer (traçabilité des hotfix)
- ADR-700 : Plan de tests d'intégration (validation provisioners + image + e2e)
- ADR-800 : Publication Azure Marketplace (16 tests certification)
- ADR-804 : Politiques certification Microsoft Marketplace (veille CVE)
- Issue [#4](https://github.com/michel-heon/semantic-media-wiki-marketplace/issues/4) : Certification Marketplace (T1-T11)
- Rapport `docs/Certification/2026-06-13-partner.pdf` : re-notification CVE 200.5.8
- Rapport `docs/Certification/2026-06-02-partner.pdf` : première notification mêmes CVE
