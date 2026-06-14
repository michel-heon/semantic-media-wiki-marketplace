# Documentation — smw-marketplace

Index de toute la documentation du projet **Cotechnoe SMW — Linked Open Data Wiki Platform** (offre Azure Marketplace).

---

## Structure

```
docs/
├── adr/                          Architecture Decision Records
├── architecture/                 Diagrammes et notes d'architecture
├── Partner/                      Contenu Partner Center (champs, logos)
├── Certification/                Rapports de certification Azure
├── vm-live-drift/                Registre des écarts VM live ↔ Packer (ADR-619)
├── scrum/                        Backlog, épopées, sprints
├── screenshots/                  Captures visuelles de l'offre
├── cotechnoe.github.io           Sous-module site GitHub Pages
└── smw6-azure-marketplace-docs   Sous-module documentation publique
```

---

## ADR — Architecture Decision Records

[`docs/adr/`](./adr/) — Toutes les décisions architecturales, techniques et métier du projet.

| Plage | Domaine |
|-------|---------|
| 000–099 | META — Processus, IA, gouvernance |
| 200–299 | INFRA — Infrastructure Azure |
| 300–399 | SEC — Sécurité et certification |
| 600–699 | DEVOPS — Scripts, Packer, CI/CD |
| 700–799 | TEST — Plans et protocoles de test |
| 800–899 | BIZ — Publication Marketplace, branding |

→ [Index complet des ADRs](./adr/README.md)

---

## Partner Center

[`docs/Partner/`](./Partner/) — Valeurs de référence pour tous les champs Partner Center.

| Fichier | Contenu |
|---------|---------|
| [`partner-center-questions.md`](./Partner/partner-center-questions.md) | Offer listing, Plan listing, Pricing — valeurs cibles à saisir |
| `cotechnoe-smw-logo-216.png` | Logo Cotechnoe SMW 216×216 px (champ "Grand") |
| `cotechnoe-smw-logo-90.png` | Logo Cotechnoe SMW 90×90 px (champ "Moyen") |
| `cotechnoe-smw-logo-48.png` | Logo Cotechnoe SMW 48×48 px (champ "Petit") |

---

## Architecture

[`docs/architecture/`](./architecture/) — Vue d'ensemble de l'architecture de la solution.

- [`smw-azure-marketplace-architecture.md`](./architecture/smw-azure-marketplace-architecture.md)

---

## Certification

[`docs/Certification/`](./Certification/) — Rapports de résultats de certification Azure Marketplace.

---

## VM Live Drift Registry

[`docs/vm-live-drift/`](./vm-live-drift/) — Registre des écarts entre l'image
SMW VM publiée (gallery / Marketplace) et le code Packer du repo. Garantit
la traçabilité bidirectionnelle entre rapport Partner Center, fix Packer
et image publiée.

→ Décision fondatrice : [ADR-619](./adr/619-DEVOPS-registre-drift-vm-live-vs-packer.md).

---

## Scrum

[`docs/scrum/`](./scrum/) — Artefacts agiles du projet.

| Fichier | Contenu |
|---------|---------|
| [`personas.md`](./scrum/personas.md) | Personas cibles (Thomas, Nadia, Jérôme…) |
| [`epics.md`](./scrum/epics.md) | Épopées |
| [`user-stories.md`](./scrum/user-stories.md) | User stories |
| [`sprint-plan.md`](./scrum/sprint-plan.md) | Plan de sprint courant |

---

## Documentation publique

- **Site GitHub Pages** : [`cotechnoe.github.io`](./cotechnoe.github.io) (sous-module)
- **Docs utilisateur** : [`smw6-azure-marketplace-docs`](./smw6-azure-marketplace-docs) (sous-module → publié sur `cotechnoe.github.io`)
