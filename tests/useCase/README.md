# tests/useCase — Cas d'usage / Use Cases

Scripts de démonstration pour populer le wiki SMW et valider la preuve de concept marketplace.

*Demonstration scripts to populate the SMW wiki and validate the marketplace proof of concept.*

## Contenu / Contents

| Fichier / File | Description |
|---|---|
| `populate-wiki.py` | Script Python de population du wiki avec contenu bilingue FR/EN |

## populate-wiki.py

Popule le wiki Semantic MediaWiki avec du contenu bilingue (français/anglais) structuré autour de trois thèmes centraux pour la démonstration marketplace Azure.

*Populates the Semantic MediaWiki instance with bilingual (French/English) content structured around three central themes for the Azure Marketplace demonstration.*

### Thèmes / Themes

- **Intelligence artificielle** — IA, apprentissage automatique, LLM, IA générative
- **Souveraineté numérique** — RGPD, cloud souverain, protection des données
- **Québec** — Mila, Scale AI, langue française, écosystème IA

### Pages créées / Pages created

| Type | Nombre | Exemples |
|---|---|---|
| Propriétés SMW | 7 | `Property:Domaine`, `Property:Langue`, `Property:Titre anglais` |
| Templates | 1 | `Template:Infobox concept numérique` |
| Catégories | 5 | `Category:Intelligence artificielle`, `Category:Québec` |
| Pages de contenu | 13 | `Intelligence artificielle`, `Mila`, `Souveraineté numérique`, etc. |
| **Total** | **26** | |

### Prérequis / Prerequisites

- Python 3.6+ (stdlib uniquement, aucune dépendance externe)
- VM SMW accessible avec l'API MediaWiki active
- Identifiants admin MediaWiki

### Utilisation / Usage

```bash
# Avec les valeurs par défaut (VM de dev standard)
python3 tests/useCase/populate-wiki.py

# Avec une URL et des credentials personnalisés
python3 tests/useCase/populate-wiki.py \
  --wiki-url https://smw-dev-20260519.canadacentral.cloudapp.azure.com \
  --user WikiAdmin \
  --password WikiAdmin2026

# Avec l'IP directement (contourne les problèmes DNS)
python3 tests/useCase/populate-wiki.py \
  --wiki-url https://20.151.0.200
```

### Pages clés pour les captures d'écran / Key pages for screenshots

| URL | Description |
|---|---|
| `/wiki/Main_Page` | Page d'accueil avec requête SMW en direct |
| `/wiki/Portail:Numérique_et_IA` | Portail thématique avec 4 requêtes SMW |
| `/wiki/Intelligence_artificielle` | Article avec infobox SMW |
| `/wiki/Semantic_MediaWiki` | Démo complète des requêtes SMW |
| `/wiki/Special:SemanticMediaWiki` | Statut de l'extension SMW |
| `/wiki/Special:Statistics` | Statistiques du wiki |
| `/wiki/Special:Browse/Intelligence_artificielle` | Navigation par propriétés SMW |
