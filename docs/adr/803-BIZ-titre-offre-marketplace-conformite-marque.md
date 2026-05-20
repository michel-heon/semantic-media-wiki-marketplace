---
adr: 803
title: "Titre Offre Azure Marketplace — Conformité Politique Marque Microsoft (100.1.1.1)"
status: "accepted"
date: 2026-05-20
superseded_by: null
replaces: null
related_adrs: [800, 802]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "business"
  impact: "high"
  quality:
    - "compliance"
    - "usability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "azure"
    - "marketplace"

tags: ["azure-marketplace", "certification", "partner-center", "trademark", "listing-title", "100.1.1.1"]
stakeholders: ["@dev-team", "@architecture-team"]
effort: "low"
---

# ADR 803: Titre Offre Azure Marketplace — Conformité Politique Marque Microsoft (100.1.1.1)

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2026-05-20 |
| **Stakeholders** | @dev-team, @architecture-team |
| **Impact** | 🔴 Élevé (bloquant certification) |
| **Effort Implémentation** | 🟢 Faible (changement Partner Center) |
| **Risque Technique** | 🟢 Faible |

---

## 🎯 Contexte & Problème

### Problème

Lors de la soumission du 05/20/2026, le rapport de certification Azure Marketplace a retourné le statut **"Attention needed"** avec l'erreur suivante :

> **100.1.1.1 — Inaccurate title**  
> "The offer listing contains Microsoft trademarked or copyrighted material in [Listing Title]."

Le titre soumis était : **`Semantic MediaWiki Cloud Edition — Azure Virtual Machines`**

L'expression **"Azure Virtual Machines"** est une marque déposée de Microsoft. Son utilisation directe dans le titre d'une offre tierce est interdite par la politique de contenu Microsoft Marketplace.

Ce blocage s'est produit à trois reprises :
- Soumission du 05/19/2026 : titre `Semantic MediaWiki — Azure VM` → rejet 100.7.1
- Soumission du 05/20/2026 : titre `Semantic MediaWiki Cloud Edition — Azure Virtual Machines` → rejet 100.1.1.1
- Soumission du 05/20/2026 : titre `Semantic MediaWiki Cloud Edition — Wiki Platform for Azure` → rejet 100.7.1

**Constat** : le mot **"Azure"** est lui-même une marque Microsoft. Toute formulation incluant "Azure" (y compris "for Azure", "on Azure") est susceptible d'être rejetée dans le titre d'une offre tierce.

### Contraintes

- **Microsoft Marketplace Policy** : Interdit l'utilisation de marques Microsoft (ex. "Azure Virtual Machines", "Azure VM") comme composante principale du titre d'une offre tierce.
- **Usage descriptif autorisé** : Les formulations `for Azure`, `on Azure`, `powered by Azure` sont tolérées car elles désignent la plateforme d'hébergement de façon descriptive, sans s'approprier le nom d'un produit Microsoft.

---

## ✅ Décision

### Titre retenu

> **`Semantic MediaWiki Cloud — Linked Data Wiki Platform`**

### Justification

| Critère | Explication |
|---------|-------------|
| Conformité marque | Aucune marque Microsoft (ni "Azure", ni "Virtual Machines", ni "Cloud" Microsoft) |
| Web sémantique | "Linked Data" positionne clairement dans l'écosystème RDF/SPARQL/Web sémantique |
| Différenciation | "Wiki Platform" décrit l'usage final ; "Cloud" indique le mode de déploiement |
| Concision | Lisible dans les listes de résultats Marketplace |

### Règle générale à retenir

| ❌ Interdit | ✅ Autorisé |
|------------|------------|
| `... — Azure Virtual Machines` | Nom produit sans référence Microsoft |
| `... Azure VM` | Référence à Linked Data, Web sémantique |
| `... for Azure` | Description fonctionnelle neutre |
| `... on Azure` | Termes du domaine (Wiki, Knowledge, Semantic) |
| `Microsoft Azure MediaWiki` | — |

---

## 📋 Implémentation

**Chemin Partner Center** :  
`Marketplace offers → Semantic MediaWiki Cloud Edition → Offer listing → Listing title`

**Valeur à saisir** : `Semantic MediaWiki Cloud — Linked Data Wiki Platform`

**Action** : Modifier le champ, sauvegarder, republier l'offre.

---

## 📚 Références

- [Microsoft Marketplace General Listing and Offer Policies](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#100-general)
- [Azure Virtual Machine Certification Policies — 100.1.1.1](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#1001-vm-images)
- Rapport certification 05/19/2026 : `docs/Certification/2026-05-19-partner.pdf`
- Rapport certification 05/20/2026 : (screenshot joint dans Partner Center)
