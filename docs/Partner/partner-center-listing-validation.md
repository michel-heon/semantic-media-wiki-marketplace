# Partner Center — Validation conformité du listing

**Date validation** : 2026-06-08
**Issue** : [#4](https://github.com/michel-heon/semantic-media-wiki-marketplace/issues/4) — T9
**ADRs** : [ADR-803](../adr/803-BIZ-titre-offre-marketplace-conformite-marque.md), [ADR-804](../adr/804-BIZ-politiques-certification-microsoft-marketplace.md)

---

## Synthèse

| Champ | Valeur retenue | Longueur | Limite | Statut |
|-------|----------------|----------|--------|--------|
| **Title** | `Cotechnoe SMW — Linked Open Data Wiki Platform` | 46 | 50 | ✅ |
| **Search results summary** | `Self-hosted Linked Open Data wiki platform with built-in knowledge-graph and SPARQL endpoint.` | 93 | 100 | ✅ |
| **Short description** | (voir partner-center-questions.md Q3) | 1919 | 2047 | ✅ |
| **Long description (HTML)** | (voir partner-center-questions.md Q3) | 4744 | 5000 | ✅ |
| **Plan summary** | `Cotechnoe SMW (Semantic MediaWiki 6.0) on Ubuntu 22.04 LTS. Pre-configured. Per-vCPU billing.` | 93 | 100 | ✅ |
| **Plan description** | (voir partner-center-questions.md Q5) | ~2 200 | 3000 | ✅ |

---

## Checklist 100.1.x — Proposition de valeur et exigences de l'offre

### 100.1.1 — Titre

| Critère | Statut | Justification |
|---------|--------|---------------|
| Descriptif | ✅ | "Linked Open Data Wiki Platform" décrit le cas d'usage |
| Exact | ✅ | Produit livre effectivement une plateforme wiki LOD |
| Cohérent Marketplace ↔ sites tiers | ✅ | Aligné avec [cotechnoe.github.io](https://cotechnoe.github.io/smw6-azure-marketplace-docs/) |
| Pas de marque déposée tierce | ✅ | Sans "Azure", "Microsoft", "MediaWiki", "Wikipedia", "Wikimedia" — ADR-803 |
| Si open source repackagé : nom vendeur | ✅ | Préfixe "Cotechnoe" présent |

### 100.1.2 — Résumé (Search results summary)

| Critère | Statut | Justification |
|---------|--------|---------------|
| ≤ 100 caractères | ✅ | 93/100 |
| Concis | ✅ | Une phrase |
| Décrit l'offre et son usage | ✅ | "wiki platform … knowledge-graph … SPARQL endpoint" |
| Pas de marques tierces | ✅ | Suppression d'"Azure" et "MediaWiki" du résumé original |

> **Historique** : version initiale (139 chars) dépassait la limite et contenait
> "Azure" + "MediaWiki" — risque 100.7.1. Corrigé le 2026-06-08.

### 100.1.3 — Description

| Critère | Présence | Emplacement |
|---------|----------|-------------|
| **Audience identifiée** | ✅ | "Universities and research institutions / Enterprise knowledge teams / Compliance and quality teams / IT and documentation teams" |
| **Valeur unique** | ✅ | "self-hosted Linked Open Data knowledge graph … built-in SPARQL endpoint … no SQL or data engineer required" |
| **Prérequis** | ✅ | VM sizes B2ms/B4ms/D2s_v3/D4s_v3/D8s_v3, OS disk 50 GB, data disk 128 GB |
| **Limitations** | ✅ | "self-signed certificate at first boot — replace with Let's Encrypt"; "MySQL bound to localhost" |
| **Marketing comparatif** | ❌ ABSENT (conforme) | Aucun "better than", "vs.", "competitor", "outperforms" |
| **Logos concurrents** | ❌ ABSENT (conforme) | Aucun logo tiers dans la description |

### 100.1.4 — Contenu non-anglais

| Critère | Statut | Action |
|---------|--------|--------|
| Description 100 % anglais | ✅ | Aucun mot français détecté (script de validation 2026-06-08) |
| Mention "available in [French]" | ⚪ Non requise | La description n'est pas multilingue → clause inapplicable |

> **Note** : Si une description française est ajoutée plus tard à Partner
> Center (champ multilingue), il faudra alors ajouter au début ou à la fin :
> `This application is available in [French].`

### 100.1.5 — Présence active

| Critère | Statut | Justification |
|---------|--------|---------------|
| Au moins un plan public | ✅ | Plan `standard` configuré en BYOL/Get It Now (ADR-800) |

---

## Checklist 100.2.x — Découvrabilité

| Critère | Statut | Valeur |
|---------|--------|--------|
| **100.2.1** Catégories (max 2) | ✅ | Web → Blogs & CMS · IT & Management Tools → Business Applications |
| **100.2.2** Keywords (pas de concurrents/catégories) | 🟡 À renseigner | Suggérés : `semantic-wiki`, `knowledge-graph`, `linked-open-data`, `sparql`, `cms` |
| **100.2.4** Plans groupés sous un seul listing | ✅ | Plan `standard` unique (extensions futures via plans additionnels) |

---

## Checklist 100.7.x — Propriété intellectuelle tierce

| Critère | Statut | Justification |
|---------|--------|---------------|
| **100.7.1** Pas de marque déposée tierce dans titre/résumé/description courte | ✅ | Validation script 2026-06-08 — aucun "Azure"/"Microsoft"/"MediaWiki"/"Wikipedia" dans Title et Search results summary |
| **100.7.1** Marques tierces dans description longue uniquement en référence légitime au composant | ✅ | "Semantic MediaWiki", "MediaWiki", "Wikipedia" mentionnés comme noms officiels des composants open source, conforme usage descriptif (fair use) |
| Licences open source citées | ✅ | "open-source" mentionné — détail dans la documentation publique [cotechnoe.github.io](https://cotechnoe.github.io/smw6-azure-marketplace-docs/) |

---

## Méthode de validation

Script Python exécuté localement (2026-06-08) extrayant les champs depuis
`docs/Partner/partner-center-questions.md` et vérifiant :

1. **Longueurs** : `len(field) <= max_chars`
2. **Marques tierces dans titre** : recherche substring de `azure`, `microsoft`, `mediawiki`, `wikipedia`, `wikimedia`
3. **Contenu non-anglais** : indicateurs `é è ê à ç ô î û` + mots clés français (`le`, `la`, `les`, `des`, `une`, `sont`, `avec`)
4. **Critères 100.1.3** : présence de mots-clés audience, valeur unique, prérequis, limitations
5. **Marketing comparatif** : absence de `better than`, `vs.`, `competitor`, `outperforms`

Reproductible via `docs/Partner/validate-listing.sh` (à créer en CI ultérieurement).

---

## Action items résiduels

- [ ] Renseigner les **keywords** dans Partner Center (suggestion : `semantic-wiki, knowledge-graph, linked-open-data, sparql, wiki-cms`)
- [ ] Uploader le **logo PNG 216×216** (T10) et **screenshots 1280×720** (T10)
- [ ] Renseigner la **Privacy policy URL** : `https://github.com/Cotechnoe/smw6-azure-marketplace-docs/blob/main/PRIVACY.md` (corrigée le 2026-06-08, version `server-azure-marketplace-docs` était fausse)
- [ ] Exécuter le **CTT officiel Microsoft** (T8) avant submission
- [ ] Joindre le **rapport CTT** dans Notes for certification (procédure dans [azure-ctt-procedure.md](azure-ctt-procedure.md))

---

## Références

- [ADR-803](../adr/803-BIZ-titre-offre-marketplace-conformite-marque.md) — Conformité titre/marques
- [ADR-804](../adr/804-BIZ-politiques-certification-microsoft-marketplace.md) — Politiques certification 100.x et 200.x
- [Microsoft Marketplace policies — Section 100](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#100-general-content)
- [Partner Center — Configure your VM offer listing](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-offer-listing)
- [partner-center-questions.md](partner-center-questions.md) — Sources des valeurs validées
- [azure-ctt-procedure.md](azure-ctt-procedure.md) — Procédure CTT officiel (T8)
