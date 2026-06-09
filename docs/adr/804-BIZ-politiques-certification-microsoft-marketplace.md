---
adr: 804
title: "Politiques de Certification Microsoft Marketplace — Conformité Offre VM SMW"
status: "accepted"
date: 2026-06-08
superseded_by: null
replaces: null
related_adrs: [800, 300, 200, 701]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "business"
  impact: "critical"
  quality:
    - "compliance"
    - "security"
    - "reliability"
  reversibility: "hard"
  scope: "strategic"
  tech_areas:
    - "azure"
    - "marketplace"
    - "vm"
    - "security"
    - "mediawiki"
    - "smw"

tags: ["azure-marketplace", "certification", "vm-offer", "compliance", "partner-center", "security", "linux", "packer"]
stakeholders: ["@dev-team", "@devops-team", "@architecture-team"]
effort: "high"
---

# ADR 804: Politiques de Certification Microsoft Marketplace — Conformité Offre VM SMW

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2026-06-08 |
| **Stakeholders** | @dev-team, @devops-team, @architecture-team |
| **Impact** | 🔴 Critique |
| **Effort Implémentation** | 🔴 Élevé |
| **Risque Technique** | 🔴 Élevé |

**Source officielle** : [Microsoft Marketplace Certification Policies](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies?context=/azure/marketplace/context/context) — Document v1.67, mis à jour le 26 août 2024.

---

## 🎯 Contexte & Problème

Pour publier l'offre VM Semantic MediaWiki (SMW) sur Azure Marketplace, l'image VM et son offre Partner Center doivent satisfaire l'ensemble des politiques de certification Microsoft. Ces politiques sont divisées en règles **générales (section 100)** et **spécifiques aux VM (section 200)**. Tout non-respect entraîne un refus de certification bloquant la publication.

### Questions Guidées

**1. Quel problème essayons-nous de résoudre?**
- L'offre VM SMW doit passer la certification Microsoft avant toute publication sur Azure Marketplace.
- Les politiques couvrent le contenu du listing, la sécurité de l'image, la généralisation, et les tests obligatoires.
- Un refus de certification retarde la mise en marché et nécessite des cycles correctifs coûteux.

**2. Quelles sont les contraintes et exigences?**
- **Techniques**: Image VHD Linux 64-bit, généralisée (waagent), boot réussi sur tous types de disques Azure (SSD, premium, éphémère), pas de swap sur OS disk.
- **Azure Marketplace**: Politiques 100 (générales) et 200 (VM) non négociables; validation via l'outil officiel [Azure Certification Test Tool](https://aka.ms/azurecertificationtesttool).
- **Sécurité**: Derniers patches de sécurité appliqués, OpenSSL ≥ 1.0, Azure Linux Agent ≥ 2.2.10, aucun mot de passe par défaut, pas de backdoor, historique bash effacé.
- **Open Source**: Conformité licences redistribution (GPL-2.0 MediaWiki/SMW, licences tiers).
- **Business**: Publisher enregistré sur Partner Center, plan VM billing approuvé, description testée fonctionnellement post-déploiement.

**3. Quel est l'impact si nous ne prenons pas de décision?**
- **Court terme (0-3 mois)**: Rejet de certification → publication impossible.
- **Moyen terme (3-12 mois)**: Délai de commercialisation, perte de crédibilité partenaire.
- **Long terme (12+ mois)**: Impossibilité d'atteindre le statut Azure IP Co-sell et les universités cibles.

**4. Quels facteurs influencent cette décision?**
- Exigences Microsoft non négociables (politiques légales).
- Stack Linux Ubuntu + MediaWiki + SMW + Apache + PHP + MySQL.
- Construction image via Packer (idempotente, automatisée).
- Tests de certification automatisés (Azure Certification Test Tool).

---

## ✅ Décision

Nous adoptons une **checklist de conformité structurée** basée sur les politiques officielles Microsoft Marketplace (sections 100 et 200), à intégrer dans le pipeline de build Packer et le protocole de qualification post-image (ADR-701).

### Approche Choisie

> Chaque build d'image VM passe une validation en deux phases : (1) vérification automatisée des exigences de l'image (Azure Certification Test Tool), et (2) validation manuelle du listing Partner Center selon les politiques 100.x.

### Politiques Section 100 — Générales (applicables au listing)

#### 100.1 — Proposition de valeur et exigences de l'offre

| Exigence | Statut | Action requise |
|----------|--------|----------------|
| **100.1.1 Titre** : Descriptif, exact, cohérent entre Marketplace et sites tiers. Si logiciel open source repackagé sans valeur ajoutée IP, inclure le nom du vendeur. | 🔴 À valider | Vérifier le titre de l'offre SMW dans Partner Center |
| **100.1.2 Résumé** : ≤ 100 caractères, concis, décrit l'offre et son usage | 🔴 À valider | Confirmer résumé ≤ 100 caractères dans Partner Center |
| **100.1.3 Description** : Identifie l'audience, la valeur unique, les prérequis, les limitations. Pas de marketing comparatif (logos concurrents interdits) | 🔴 À valider | Réviser la description SMW sur Partner Center |
| **100.1.4 Contenu non-anglais** : Si contenu en français, commencer ou terminer par "This application is available in [French]" | ✅ À implémenter | Ajouter la mention anglaise si description en français |
| **100.1.5 Présence active** : Au moins un plan public (Contact Me, BYOL, ou Get It Now) | ✅ Conforme | Plan BYOL ou Get It Now à maintenir |

#### 100.2 — Découvrabilité

| Exigence | Action |
|----------|--------|
| **100.2.1** : Catégories (max 2) pertinentes à l'offre SMW (ex: IT & Management Tools, Databases) | Sélectionner catégories appropriées dans Partner Center |
| **100.2.2** : Keywords pertinents; interdiction d'inclure noms de concurrents ou catégories | Valider keywords (mediawiki, semantic-wiki, knowledge-base) |
| **100.2.4** : Versions multiples d'un même produit groupées sous un seul listing avec plans distincts | Utiliser les plans Marketplace pour différentes éditions |

#### 100.3 — Éléments graphiques

| Exigence | Spécification |
|----------|--------------|
| Logo principal | `.png`, 216–350 pixels carrés |
| Logo optionnel | `.png`, 48 pixels carrés |
| Screenshots | `.png`, 1280×720 px, haute résolution, texte lisible |
| Vidéos | Hébergées sur YouTube ou Vimeo uniquement, liens directs, publiquement visibles et intégrables |

#### 100.5 — Informations de l'offre

- Conditions d'utilisation et politique de confidentialité à jour et fonctionnelles.
- Documentation disponible, détaillée, et actuelle.
- Liens "En savoir plus" fonctionnels (pas de téléchargement automatique).

#### 100.11 — Sécurité

- Pas d'exécution de code exécutable non décrit dans le listing.
- Signalement des incidents de sécurité au plus tôt.
- Pas de credentials partagés publiquement dans la page de description.

#### 100.12 — Fonctionnalité

- L'offre doit fonctionner comme décrit (SMW accessible post-déploiement).
- UI intuitive, temps de chargement signalés par des indicateurs de progression.

#### 100.14 — Testabilité

- Fournir des instructions de certification (Notes for Certification dans Partner Center).
- Comptes de test valides et environnements configurés.

---

### Politiques Section 200 — VM (applicables à l'image)

#### 200.1 — Exigences Techniques

| Exigence | Statut projet |
|----------|--------------|
| Connaissance Azure Services, VM, Storage, Networking, ARM, JSON | ✅ Couvert (ADR-200) |
| Recommandation : Azure PowerShell Az module plutôt que RM déprécié | ℹ️ Pour les scripts de validation VM |

#### 200.2 — Exigences Business

| Exigence | Action |
|----------|--------|
| Publisher enregistré sur Partner Center et approuvé pour le plan de facturation VM | ✅ Prérequis |
| Description testée fonctionnellement après déploiement VM image dans Azure | 🔴 À valider à chaque build |
| Conformité licences redistribution tiers (MediaWiki GPL-2.0, SMW GPL-2.0, PHP, MySQL) | ✅ Licences open source compatibles |

#### 200.3 — Exigences Image VM

##### 200.3.1 Général

| Exigence | Implémentation Packer/Scripts |
|----------|-------------------------------|
| Image fournie en VHD, basée sur image Azure approuvée | ✅ Ubuntu LTS depuis Azure base image |
| Déployable depuis Azure Portal ou PowerShell | ✅ Via ARM template inclus |
| Supporte au moins la taille VM recommandée par le publisher | 🔴 Documenter la taille minimale recommandée dans l'offre |
| Support VM Extensions (Azure Diagnostics, Monitoring) | ✅ À vérifier dans provisioners |
| Le nombre de disques d'une version image ne peut pas changer | ⚠️ Politique: créer nouveau SKU si reconfiguration disques |
| Image bien formée avec footer standard | ✅ Via waagent deprovision |
| VHD soumis via URI SAS valide | ✅ Géré par processus Partner Center |
| Architecture OS 64 bits | ✅ Ubuntu 64-bit |
| Taille image = multiple exact de 1 MB | ✅ Géré par Azure lors de la généralisation |
| Image déprovisionnée (généralisée) | ✅ `waagent -deprovision+user` dans provisioner |

##### 200.3.3 Linux (spécifique Ubuntu)

| Exigence | Statut | Action |
|----------|--------|--------|
| Pas de partition swap sur le disque OS | ✅ À vérifier | Confirmer via `swapon --show` dans tests |
| Distribution Linux approuvée par Azure (Ubuntu) | ✅ Conforme | Ubuntu LTS est une distro endorsée |
| Taille disque OS : 30 GB – 1023 GB | ✅ Conforme | OS disk dans cette plage |
| Taille disques données : 1 GB – 1023 GB | ✅ Conforme | Si data disk utilisé |
| Compatibilité Serial Console : `console=ttyS0` | 🔴 À vérifier | Confirmer dans kernel boot line |
| Azure Linux Agent installé (version ≥ 2.2.10) | 🔴 À vérifier | Script Packer doit installer/mettre à jour waagent |
| Serveur SSH inclus par défaut | ✅ Conforme | OpenSSH pré-installé Ubuntu |
| VM boot et reboot réussis | 🔴 Tests obligatoires | Protocole ADR-701 |
| DNS résolution réseau fonctionnelle | 🔴 Tests obligatoires | Protocole ADR-701 |
| Pas d'utilisateurs pré-existants avec mots de passe | ✅ Via `waagent -deprovision+user` |
| Boot réussi sur premium disk, standard SSD, ephemeral disk | 🔴 Tests obligatoires | Azure Certification Test Tool |
| Boot réussi avec NIC synthétique | 🔴 Tests obligatoires | Azure Certification Test Tool |
| Driver Hyper-V `hv_netvsc` installé | 🔴 À vérifier | Inclus dans kernels Ubuntu récents |

##### 200.4 — Généralisation de l'Image

| Exigence | Implémentation |
|----------|---------------|
| Image réutilisable de façon générique (généralisée) | ✅ `waagent -deprovision+user` en fin de build Packer |
| Paramètres kernel : `console=ttyS0 earlyprintk=ttyS0 rootdelay=300` | 🔴 À vérifier dans GRUB config |
| Pas de solution antivirus, outils de management remote, ou accès externe pré-installés | ✅ À confirmer — Microsoft Defender ne doit pas être pré-installé par le publisher |
| Pour Linux : voir [Generalize the Linux image without Defender](https://learn.microsoft.com/en-us/defender-endpoint/linux-resources#uninstall-defender-for-endpoint-on-linux) | ℹ️ Référence à consulter si Defender est installé |

#### 200.5 — Sécurité

| Exigence | Statut | Action |
|----------|--------|--------|
| OS et services avec tous derniers patches de sécurité | 🔴 À chaque build | `apt-get upgrade` dans provisioner |
| Pas de CVE significatifs (Common Vulnerabilities and Exposures) | 🔴 Scan requis | Outil de scan CVE (ex: `unattended-upgrades`, `trivy`) |
| OpenSSL ≥ 1.0 | ✅ Conforme | Ubuntu LTS inclut OpenSSL récent |
| Python 2.6+ recommandé | ✅ Conforme | Python 3.x inclus |
| Azure Linux Agent ≥ 2.2.10 | 🔴 À vérifier | Confirmer version dans build |
| Règles firewall désactivées sauf si l'application en dépend | ⚠️ À documenter | UFW config justifiée pour Apache/MySQL |
| Code source et image scannés pour malware | 🔴 Obligatoire | Voir [Trust and Security Services Scan](https://techcommunity.microsoft.com/blog/microsoftsecurityandcompliance/trust--security-services-scan-protecting-microsoft%E2%80%99s-software-supply-chain-from-/3953427) |
| Tâches planifiées non-OS identifiées (pas de CRON malware) | 🔴 À auditer | Documenter tout cronjob dans provisioners |
| Pas de dépendance sur usernames restreints (`Administrator`, `root`, `admin`) | ✅ Conforme | SMW utilise un user dédié |
| Historique bash/shell effacé | 🔴 À implémenter | Ajouter `history -c && cat /dev/null > ~/.bash_history` en fin de provisioner |
| VHD basé sur une image Windows/Linux approuvée Azure | ✅ Conforme | Ubuntu LTS depuis Azure base |
| Image avec seulement comptes verrouillés, pas de mot de passe par défaut | ✅ Via `waagent -deprovision+user` |
| Clés SSH de test, fichiers known_hosts, logs, certificats inutiles supprimés | 🔴 À implémenter | Nettoyage en fin de provisioner |

#### 200.6 — Tests et Certification

| Étape | Description | Outil |
|-------|-------------|-------|
| 1. Test local | Valider l'image VM dans Azure avant soumission | Azure Portal / CLI |
| 2. Certification Test Tool | Exécuter l'outil officiel de certification | [Azure Certification Test Tool](https://aka.ms/azurecertificationtesttool) |
| 3. SAS URI | Générer URI SAS avec permissions List+Read, durée ≥ 3 semaines | Azure Storage |
| 4. Format SAS URI | `<blob-endpoint>/vhds/<vhd-name>?<sas-string>` avec `sp=rl` et `sr=c` | Vérification manuelle |
| 5. Soumission Partner Center | Fournir SAS URI pour chaque VHD lors de la publication | Partner Center |

**Exigences SAS URI** :
- Permissions : List et Read uniquement (pas de Write ni Delete)
- Durée d'accès : minimum 3 semaines après création
- Date de début : 1 jour avant la date actuelle (protection UTC)

---

## 📊 Matrice de Risques par Section

| Section | Risque | Impact | Probabilité | Mitigation |
|---------|--------|--------|-------------|------------|
| 100.1.3 Description | Non-conformité contenu | 🔴 Élevé | 🟡 Moyen | Révision description avant soumission |
| 200.3.3 Linux | Boot failure sur certain type de disk | 🔴 Élevé | 🟡 Moyen | Tests Azure Certification Test Tool |
| 200.4 Généralisation | Image non généralisée | 🔴 Élevé | 🟢 Faible | `waagent -deprovision+user` obligatoire |
| 200.5 Sécurité | CVE non patchés | 🔴 Élevé | 🟡 Moyen | `apt-get upgrade` + scan CVE à chaque build |
| 200.5 Sécurité | Bash history non effacé | 🟡 Moyen | 🟡 Moyen | Script de nettoyage en fin de provisioner |
| 200.6 SAS URI | URI expirée lors de la certification | 🟡 Moyen | 🟢 Faible | Générer URI 1 jour avant soumission |
| 100.3 Graphiques | Mauvais format logo/screenshot | 🟢 Faible | 🟡 Moyen | Vérifier specs dimensions avant upload |

---

## ⚖️ Conséquences

### ✅ Positives (Bénéfices)

| Bénéfice | Valeur Attendue |
|----------|-----------------|
| Certification Microsoft obtenue | Publication SMW sur Azure Marketplace débloquée |
| Image sécurisée et sans CVE | Conformité OWASP, confiance des clients universitaires |
| Processus reproductible | Recertification simplifiée à chaque mise à jour |
| Listing conforme | Meilleure découvrabilité et crédibilité Microsoft Partner |

### ⚠️ Négatives (Risques & Limitations)

| Risque | Impact | Mitigation |
|--------|--------|------------|
| Changements futurs des politiques Microsoft | 🟡 Moyen | Veille sur [Change history](https://learn.microsoft.com/en-us/legal/marketplace/offer-policies-change-history) |
| Cycles de recertification à chaque version majeure | 🟡 Moyen | Intégrer tests de certification dans ADR-701 |
| Compatibilité avec nouvelles distributions Azure | 🟢 Faible | Utiliser toujours une Ubuntu LTS approuvée |

---

## 🔄 Checklist d'Implémentation

### Provisioners Packer — Actions requises

- [ ] Vérifier installation Azure Linux Agent ≥ 2.2.10 (`waagent --version`)
- [ ] Appliquer tous les patches sécurité (`apt-get update && apt-get upgrade -y`)
- [ ] Confirmer absence partition swap sur OS disk (`swapon --show` → vide)
- [ ] Vérifier driver `hv_netvsc` présent (`lsmod | grep hv_netvsc`)
- [ ] Vérifier paramètres kernel boot : `console=ttyS0 earlyprintk=ttyS0 rootdelay=300`
- [ ] Supprimer clés SSH de test, fichiers `known_hosts`, logs inutiles, certificats temporaires
- [ ] Effacer historique bash : `history -c && cat /dev/null > ~/.bash_history`
- [ ] Ne pas pré-installer Microsoft Defender (interdit pour les publishers d'image)
- [ ] Identifier et documenter tous les cron jobs non-OS
- [ ] Exécuter `waagent -deprovision+user -force` en dernière étape du build

### Partner Center — Actions requises

- [ ] Titre de l'offre : descriptif, exact, sans marketing comparatif
- [ ] Résumé : ≤ 100 caractères
- [ ] Description : audience, valeur unique, prérequis, limitations clairement identifiés
- [ ] Si description en français : ajouter "This application is available in [French]"
- [ ] Logo : `.png` 216–350 px carrés
- [ ] Screenshots : `.png` 1280×720 px, texte lisible
- [ ] Politique de confidentialité : URL fonctionnelle
- [ ] Conditions d'utilisation : document à jour
- [ ] Notes for Certification : instructions de déploiement et de test
- [ ] Plan minimum public (BYOL ou Get It Now)

### Validation Finale — Azure Certification Test Tool

- [ ] Déployer l'image VM dans Azure (depuis Portal ou CLI)
- [ ] Exécuter le [Azure Certification Test Tool](https://aka.ms/azurecertificationtesttool)
- [ ] Corriger tous les échecs identifiés avant soumission
- [ ] Générer SAS URI avec permissions List+Read, durée ≥ 3 semaines
- [ ] Vérifier format SAS URI : `<blob-endpoint>/vhds/<vhd-name>?<sas>` avec `sp=rl` et `sr=c`

---

## 📚 Références

| Source | URL |
|--------|-----|
| Politiques de certification Microsoft Marketplace | https://learn.microsoft.com/en-us/legal/marketplace/certification-policies |
| Historique des changements politiques | https://learn.microsoft.com/en-us/legal/marketplace/offer-policies-change-history |
| Distributions Linux approuvées Azure | https://learn.microsoft.com/en-us/azure/virtual-machines/linux/endorsed-distros |
| Azure Certification Test Tool | https://aka.ms/azurecertificationtesttool |
| Généraliser l'image Linux | https://learn.microsoft.com/en-us/azure/marketplace/azure-vm-create-using-approved-base#generalize-the-image |
| Guide publication offre VM | https://learn.microsoft.com/en-us/azure/marketplace/publisher-guide-by-offer-type |
| ADR-200 Infrastructure Azure VM | [200-INFRA-azure-infrastructure-vm-offer.md](./200-INFRA-azure-infrastructure-vm-offer.md) |
| ADR-300 Sécurité hardening VM | [300-SEC-securite-hardening-vm-certification.md](./300-SEC-securite-hardening-vm-certification.md) |
| ADR-701 Protocole qualification post-image | [701-TEST-protocole-qualification-post-image-vm.md](./701-TEST-protocole-qualification-post-image-vm.md) |
| ADR-800 Publication Azure Marketplace | [800-BIZ-publication-azure-marketplace-vm-offer.md](./800-BIZ-publication-azure-marketplace-vm-offer.md) |
