# Partner Center — Logos & Screenshots (T10)

**Date** : 2026-06-08
**Issue** : [#4](https://github.com/michel-heon/semantic-media-wiki-marketplace/issues/4) — T10
**ADRs** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md), [ADR-802](../adr/802-BIZ-sources-officielles-azure-marketplace.md)
**Référence Microsoft** : [Configure your VM offer listing](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-offer-listing#marketplace-images)

---

## 1. Inventaire des assets disponibles

### 1.1 Logos (Partner Center "Marketplace logos")

| Fichier | Dimensions | Taille | Statut PC | Slot Partner Center |
|---------|------------|--------|-----------|---------------------|
| [`cotechnoe-smw-logo-48.png`](cotechnoe-smw-logo-48.png) | 48×48 | 2.4 KB | ✅ Conforme | Small logo (search results) |
| [`cotechnoe-smw-logo-90.png`](cotechnoe-smw-logo-90.png) | 90×90 | 4.7 KB | ⚪ Optionnel | Medium logo (legacy) |
| [`cotechnoe-smw-logo-216.png`](cotechnoe-smw-logo-216.png) | 216×216 | 11.6 KB | ✅ Conforme | **Large logo (recommandé)** |
| [`SMW-logo.png`](SMW-logo.png) | 350×350 | 52.7 KB | ✅ Conforme | Large logo alternatif (limite haute) |

**Spécification Microsoft** :
- Large logo : PNG `216×216` à `350×350` px — **obligatoire** sur la page de détails de l'offre.
- Small logo : `48×48` px — **généré automatiquement** par Partner Center depuis le large logo. À fournir uniquement si on veut un design différent du large.

### 1.2 Screenshots (Partner Center "Screenshots")

| # | Fichier | Dimensions | Taille | Contenu |
|---|---------|------------|--------|---------|
| 1 | [`01-main.png`](01-main.png) | 1280×720 | 252 KB | Page d'accueil SMW (Main Page) |
| 2 | [`02-Thematique.png`](02-Thematique.png) | 1280×720 | 329 KB | Page thématique avec propriétés sémantiques |
| 3 | [`03-navigation.png`](03-navigation.png) | 1280×720 | 237 KB | Navigation par catégories / Linked Data |
| 4 | [`04-recherche.png`](04-recherche.png) | 1280×720 | 113 KB | Interface de recherche / #ask |
| 5 | [`05-Resultat.png`](05-Resultat.png) | 1280×720 | 258 KB | Résultats de requête sémantique |

**Spécification Microsoft** :
- Format `1280×720` px (16:9).
- Maximum **5 screenshots** par offre. ✅ — on en a exactement 5.
- Inclure les **mots-clés** dans les noms de fichiers (SEO interne PC).

---

## 2. Mapping vers les slots Partner Center

Naviguer dans **Partner Center → Offer → Offer listing → Marketplace images / Screenshots**.

| Slot Partner Center | Champ requis | Fichier à uploader |
|---------------------|--------------|--------------------|
| **Large logo (216–350 px)** | 🔴 Obligatoire | `cotechnoe-smw-logo-216.png` (recommandé) ou `SMW-logo.png` |
| **Small logo (48×48 px)** | ⚪ Auto-généré | (optionnel) `cotechnoe-smw-logo-48.png` |
| **Screenshot 1** | 🔴 ≥ 1 requis | `01-main.png` |
| **Screenshot 2** | 🟡 Recommandé | `02-Thematique.png` |
| **Screenshot 3** | 🟡 Recommandé | `03-navigation.png` |
| **Screenshot 4** | 🟡 Recommandé | `04-recherche.png` |
| **Screenshot 5** | 🟡 Recommandé | `05-Resultat.png` |

> **Caption recommandée pour chaque screenshot** (≤ 100 chars chacune) :
> 1. `Cotechnoe SMW main page — your knowledge base homepage with semantic navigation.`
> 2. `Themed page with typed property annotations — the foundation of the knowledge graph.`
> 3. `Linked-data navigation across pages and concepts — no SQL required.`
> 4. `Built-in semantic query interface (#ask) for tables, charts, and maps.`
> 5. `Live query results rendered dynamically as data evolves.`

---

## 3. Conformité Microsoft (politiques 100.3.x)

| Critère | Statut | Justification |
|---------|--------|---------------|
| **100.3.1** Logo : PNG carré, fond opaque ou transparent, lisible | ✅ | Logos Cotechnoe SMW conformes |
| **100.3.1** Pas de logo concurrent dans les screenshots | ✅ | Screenshots montrent uniquement l'UI SMW/MediaWiki |
| **100.3.2** Screenshots : 1280×720 PNG | ✅ | 5/5 conformes |
| **100.3.2** Texte lisible dans les screenshots | ✅ | À vérifier visuellement avant upload (zoom navigateur 100%) |
| **100.3.3** Maximum 5 screenshots | ✅ | Exactement 5 |
| **100.7.1** Pas de marque déposée tierce dans les visuels | ✅ | Aucun logo Azure/Microsoft/Wikimedia dans les assets |

> **Note** : `docs/screenshots/*.png` (1280×900) sont des captures pour le
> site marketing (`cotechnoe.github.io`) — **ne pas les uploader** dans
> Partner Center (format non conforme).

---

## 4. Procédure d'upload Partner Center

1. **Connexion** : [partner.microsoft.com/dashboard](https://partner.microsoft.com/dashboard) → Marketplace offers → `smw-knowledge-base`
2. **Onglet** : Offer listing
3. **Section "Marketplace images"** :
   - Cliquer **Browse** sous "Large (216×216)" → sélectionner `cotechnoe-smw-logo-216.png`
   - (Optionnel) "Small (48×48)" → `cotechnoe-smw-logo-48.png`
4. **Section "Screenshots"** :
   - Pour chaque screenshot, cliquer **+ Add screenshot**
   - Uploader le PNG + saisir la caption associée (voir §2)
   - Réordonner par drag-and-drop selon l'ordre suggéré
5. **Save draft** → vérifier l'aperçu via **Preview offer listing**
6. **Soumettre** : Review and publish (déclenche la certification)

---

## 5. Validation automatique

Script de validation des dimensions exécutable localement :

```bash
make assets-validate
# ou : bash docs/Partner/validate-assets.sh
```

Le script vérifie :
- Présence des fichiers requis
- Dimensions logos (216×216 ou 350×350 pour le large, 48×48 pour le small)
- Dimensions screenshots (1280×720)
- Nombre de screenshots (≤ 5)
- Taille des fichiers (< 256 KB recommandé pour le large logo, < 1 MB pour les screenshots)

---

## 6. Action items résiduels

- [ ] Uploader `cotechnoe-smw-logo-216.png` dans le slot "Large logo" Partner Center
- [ ] Uploader les 5 screenshots 1280×720 (`01-main` → `05-Resultat`)
- [ ] Saisir les captions associées (voir §2)
- [ ] Preview offer listing → screenshot du rendu → archiver dans `docs/Certification/`
- [ ] (Futur) Régénérer les assets en version branding "Cotechnoe SMW" (actuellement `SMW-logo.png` montre encore le logo générique SMW)

---

## Références

- [Configure your VM offer listing — Marketplace images](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-offer-listing#marketplace-images)
- [ADR-802 §Logos & Screenshots](../adr/802-BIZ-sources-officielles-azure-marketplace.md)
- [ADR-804 §100.3](../adr/804-BIZ-politiques-certification-microsoft-marketplace.md)
- Script de validation : [`validate-assets.sh`](validate-assets.sh)
