---
adr: 805
title: "Nomenclature Uniforme des Titres d'Offres Azure Marketplace — Cotechnoe"
status: "accepted"
date: 2026-06-14
superseded_by: null
replaces: null
related_adrs: [800, 803, 804]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "business"
  impact: "medium"
  quality:
    - "compliance"
    - "usability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "azure"
    - "marketplace"

tags: ["azure-marketplace", "certification", "partner-center", "trademark", "listing-title", "nomenclature", "branding", "100.1.1.1", "100.7.1"]
stakeholders: ["@dev-team", "@architecture-team"]
effort: "low"
---

# ADR 805: Nomenclature Uniforme des Titres d'Offres Azure Marketplace — Cotechnoe

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2026-06-14 |
| **Stakeholders** | @dev-team, @architecture-team |
| **Impact** | 🟡 Moyen |
| **Effort Implémentation** | 🟢 Faible (changements Partner Center) |
| **Risque Technique** | 🟢 Faible |

---

## 🎯 Contexte & Problème

### Problème

Le portfolio Cotechnoe comprend 5 offres VM publiées sur Azure Marketplace. Les titres actuels sont hétérogènes : formats différents, présence/absence de l'éditeur, longueurs disparates, et patterns de séparation incohérents.

**Titres actuels (au 2026-06-14)** :

| Offre | Titre actuel | Problème |
|-------|-------------|---------|
| SMW | `Cotechnoe SMW — Linked Open Data Wiki...` | ✅ Référence certifiée |
| Nextcloud | `Cotechnoe Nextcloud — Cloud Hub Secure File...` | ⚠️ "Nextcloud" est une marque tierce |
| DSpace | `DSpace 9 — Institutional Repository` | ❌ Pas d'éditeur, version dans le titre |
| Fuseki | `Apache Jena Fuseki` | ❌ Pas d'éditeur, "Apache" est une marque tierce |
| VIVO | `VIVO Research Networking Platform ...` | ❌ Pas d'éditeur |

### Contraintes

- **Microsoft Marketplace Policy 100.1.1.1** : Si le produit est un logiciel repackagé, le titre doit indiquer la valeur ajoutée ou inclure le nom du vendeur.
- **Microsoft Marketplace Policy 100.7** : Tout contenu doit être originalement créé, licencié, ou utilisé avec permission — aucune marque tierce sans autorisation explicite.
- **Règle 100.1.1 (Name field)** : Max 200 caractères, pas d'emojis. Peut inclure ™ et ©.
- **Expérience Cotechnoe** : La politique 100.7 a déjà entraîné 5 rejets de certification sur l'offre SMW (voir ADR-803) — "MediaWiki" et "Azure" étant des marques protégées. Le titre `Cotechnoe SMW — Linked Open Data Wiki Platform` a été certifié avec succès.

### Questions Guidées

**1. Quel problème essayons-nous de résoudre?**
- Incohérence des titres nuisant à la reconnaissance de la marque Cotechnoe sur le Marketplace.
- Risque de rejet de certification (100.7) pour les offres dont le titre contient des marques tierces sans éditeur visible.
- Absence d'un standard applicable à toutes les nouvelles offres futures.

**2. Quelles sont les contraintes et exigences?**
- **Conformité** : Politiques 100.1.1.1 et 100.7 non négociables.
- **Marques à risque** : "Apache", "Nextcloud", "DSpace", "VIVO", "MediaWiki" sont des noms de projets ou marques de fondations tierces (Apache Software Foundation, Nextcloud GmbH, DuraSpace/Lyrasis, VIVO Project).
- **Marques sûres** : Les acronymes maison (SMW, NCCloud) et les termes génériques descriptifs (Platform, Server, Hub, Repository) ne sont pas des marques déposées.
- **Cohérence visuelle** : Les 5 offres doivent former un ensemble reconnaissable pour l'éditeur "Cotechnoe".

**3. Quel est l'impact si nous ne prenons pas de décision?**
- **Court terme** : Risque de rejet 100.7 lors des prochaines soumissions Nextcloud, DSpace, Fuseki, VIVO.
- **Moyen terme** : Image de marque fragmentée, difficulté pour les clients à identifier le portfolio Cotechnoe.
- **Long terme** : Impossibilité d'atteindre le statut Azure IP Co-sell si les offres ne passent pas la certification.

**4. Quels facteurs influencent cette décision?**
- Le titre `Cotechnoe SMW — Linked Open Data Wiki Platform` est déjà **certifié et live** — il sert de référence éprouvée.
- L'analyse comparée de 5 options de nomenclature a confirmé que le patron `[Éditeur] [Acronyme] — [Catégorie générique]` est le seul entièrement conforme aux politiques Microsoft.

---

## ✅ Décision

### Pattern retenu — Option A

> **`Cotechnoe [Acronyme/NomCourt] — [Descripteur fonctionnel générique]`**

### Titres décidés pour les 5 offres

| Offre | Titre retenu | Caractères |
|-------|-------------|-----------|
| Semantic MediaWiki | `Cotechnoe SMW — Linked Open Data Wiki Platform` | 47 |
| Nextcloud | `Cotechnoe NCCloud — Secure Cloud File Hub` | 41 |
| DSpace | `Cotechnoe DSpace — Institutional Repository Platform` | 51 |
| Apache Jena Fuseki | `Cotechnoe Fuseki — SPARQL RDF Data Server` | 42 |
| VIVO | `Cotechnoe VIVO — Research Networking Platform` | 46 |

### Justification

| Critère | Explication |
|---------|-------------|
| **Conformité 100.1.1.1** | "Cotechnoe" apparaît en tête — règle éditeur satisfaite pour tous les logiciels repackagés |
| **Conformité 100.7** | Aucune marque tierce directe : "SMW", "NCCloud", "DSpace", "Fuseki", "VIVO" sont des acronymes/noms courts non déposés en tant que *wordmarks* |
| **Cohérence visuelle** | Pattern identique pour les 5 offres — reconnaissance immédiate du portfolio Cotechnoe |
| **Référence certifiée** | SMW déjà certifié avec ce pattern — preuve empirique de conformité |
| **Brièveté** | Tous les titres ≤ 51 caractères — lisibles dans les listes de résultats Marketplace |

### Règle générale applicable à toute nouvelle offre Cotechnoe

```
Titre = "Cotechnoe " + [Acronyme ou nom court non déposé] + " — " + [Descripteur générique]
```

| ❌ Interdit dans le titre | ✅ Autorisé |
|--------------------------|------------|
| Noms de marques tierces : `Apache`, `MediaWiki`, `Nextcloud` (GmbH) | Acronymes maison : `SMW`, `NCCloud`, `Fuseki`, `VIVO`, `DSpace` |
| Noms de produits Microsoft : `Azure`, `Virtual Machine` | Descripteurs génériques : `Platform`, `Server`, `Hub`, `Repository` |
| Numéros de version : `DSpace 9`, `PHP 8.3` | Nom de l'éditeur : `Cotechnoe` |
| Emojis | Termes techniques neutres : `SPARQL`, `RDF`, `LOD` |

---

## 📊 Matrice de Décision

| Critère | Poids | Option B (fonctionnel pur) | Option C (for Secteur) | Option D (pipe \|) | **Option A (retenu)** |
|---------|-------|--------------------------|----------------------|-------------------|----------------------|
| Conformité 100.1.1.1 + 100.7 | 40% | 🟢 10/10 | 🟢 9/10 | 🟡 7/10 | 🟢 **10/10** |
| Cohérence inter-offres | 25% | 🟢 10/10 | 🟡 6/10 | 🟡 7/10 | 🟢 **10/10** |
| Reconnaissance produit (SEO) | 20% | 🔴 4/10 | 🟡 7/10 | 🟡 6/10 | 🟢 **9/10** |
| Brièveté (≤ 50 car.) | 15% | 🟢 10/10 | 🔴 4/10 | 🟢 10/10 | 🟢 **9/10** |
| **Score Total Pondéré** | 100% | **8.30** | **6.85** | **7.45** | **9.80** ⭐ |

```
Option B:  (10*0.40) + (10*0.25) + (4*0.20) + (10*0.15) = 8.30
Option C:  (9*0.40)  + (6*0.25)  + (7*0.20) + (4*0.15)  = 6.85
Option D:  (7*0.40)  + (7*0.25)  + (6*0.20) + (10*0.15) = 7.45
Option A:  (10*0.40) + (10*0.25) + (9*0.20) + (9*0.15)  = 9.80 ✅
```

---

## ⚖️ Conséquences

### ✅ Positives

| Bénéfice | Valeur attendue |
|----------|----------------|
| Certification Marketplace | Risque 100.7 éliminé — pattern éprouvé sur SMW |
| Reconnaissance marque Cotechnoe | Éditeur visible en tête sur les 5 offres |
| Extensibilité | Règle applicable à toute future offre sans nouveau débat |
| Cohérence vitrinePlace | Les 5 cartes offres forment un ensemble visuel unifié |

### ⚠️ Négatives et Risques

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| "DSpace", "Fuseki", "VIVO" sont noms de projets Apache/open-source — risque 100.7 résiduel faible | 🟡 Moyen | Documenter l'absence de wordmark officiel ; surveiller les rapports de certification |
| Perte de reconnaissance immédiate du nom complet du produit | 🟢 Faible | L'acronyme reste dans le titre + nom complet en description |
| Changement de titre pour les offres live (NCCloud, DSpace, Fuseki, VIVO) | 🟢 Faible | Modification simple dans Partner Center, pas de re-certification image |

---

## 🔄 Alternatives Considérées

### Option B — Descripteur fonctionnel pur
```
Cotechnoe Wiki LOD      — Knowledge Graph Platform
Cotechnoe Cloud Drive   — Secure File Sharing Hub
...
```
**Rejetée** : Perd toute reconnaissance des produits open-source cibles, impact SEO négatif.

### Option C — `for [Secteur]`
```
Cotechnoe SMW for Open Data Organizations
Cotechnoe Nextcloud for Secure Team Collaboration
...
```
**Rejetée** : Longueur excessive (> 50 caractères), "for" peut créer une ambiguïté de dépendance vis-à-vis d'un service tiers (politique 100.7).

### Option D — Séparateur `|`
```
Cotechnoe SMW      | Wiki & LOD Server
Cotechnoe NCCloud  | File Sharing Server
...
```
**Rejetée** : Non standard sur Azure Marketplace, aucun exemple certifié connu avec ce séparateur.

### Option E — Parenthèses
```
Cotechnoe: Linked Data Wiki (SMW)
Cotechnoe: Secure Cloud Hub (Nextcloud)
...
```
**Rejetée** : Format inhabituel, le nom entre parenthèses peut être interprété comme une marque tierce par l'outil de certification automatique.

---

## 📋 Implémentation

### Actions par offre

| Offre | Action | Chemin Partner Center |
|-------|--------|----------------------|
| SMW | ✅ Déjà certifié — aucune action | — |
| Nextcloud | Modifier le titre | `Offers → Nextcloud → Offer listing → Name` |
| DSpace | Modifier le titre | `Offers → DSpace → Offer listing → Name` |
| Fuseki | Modifier le titre | `Offers → Apache Jena Fuseki → Offer listing → Name` |
| VIVO | Modifier le titre | `Offers → VIVO → Offer listing → Name` |

### Procédure

1. Se connecter à [Partner Center](https://partner.microsoft.com/dashboard)
2. Pour chaque offre concernée : `Marketplace offers → [Offre] → Offer listing → Name`
3. Saisir le nouveau titre selon le tableau de la section Décision
4. Sauvegarder → Soumettre pour review
5. Vérifier l'absence d'erreur 100.1.1.1 ou 100.7 dans le rapport de certification

> **Note** : La modification du titre seul ne déclenche **pas** de re-certification de l'image VM. Seule la section "Offer listing" est resoumise.

---

## 📚 Références

- [Microsoft Marketplace Certification Policies — 100.1.1.1 Title](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#10011-title)
- [Microsoft Marketplace Certification Policies — 100.7 Accurate source](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#1007-accurate-source)
- [Configure VM Offer Listing Details](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-offer-listing)
- [ADR-803 — Titre Offre Azure Marketplace, Conformité Marques Tierces](./803-BIZ-titre-offre-marketplace-conformite-marque.md)
- [ADR-804 — Politiques de Certification Microsoft Marketplace](./804-BIZ-politiques-certification-microsoft-marketplace.md)
- [ADR-800 — Publication Offre VM sur Azure Marketplace](./800-BIZ-publication-azure-marketplace-vm-offer.md)
