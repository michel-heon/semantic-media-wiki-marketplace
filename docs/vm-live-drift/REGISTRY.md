# 📊 Drift Registry — VM Live vs Packer — smw-marketplace

> 1 ligne = 1 écart entre l'image SMW VM live (ou plan publié gallery /
> Marketplace) et le code Packer du repo. Pour chaque drift, créer
> `DRIFT-NNN-<slug>.md` détaillé. Voir [README.md](./README.md) pour la
> procédure.

---

## 🔥 Drifts actifs

| ID  | Slug | Détecté sur | Image en cause | Composant | Statut macro | Sous-état bloquant | Packer cible | ADR | Smoke test | Issue GH |
|-----|------|-------------|----------------|-----------|--------------|---------------------|--------------|-----|------------|----------|
| DRIFT-000 | [cve-patches-ubuntu-200.5.8](./DRIFT-000-cve-patches-ubuntu-200.5.8.md) | Partner Center 2026-06-13 (rapport AMAT 200.5.8) | `standard/6.0.20260517` | OS Ubuntu (apt — libgnutls30, libarchive13, bind9*, libwbclient0) | `in-packer` | **`image-submitted`** (CTT MSI + Partner Center submission `6.0.20260609`) | `packer/provisioners/01-install-base.sh` §2.b (USN gate) | [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md), [ADR-619](../adr/619-DEVOPS-registre-drift-vm-live-vs-packer.md), [ADR-804](../adr/804-BIZ-politiques-certification-microsoft-marketplace.md) | `make vm-security-check` Test #16 + image `6.0.20260609` validée 2026-06-14 | [#4](https://github.com/michel-heon/semantic-media-wiki-marketplace/issues/4) |

---

## ✅ Drifts résolus

_(aucun pour l'instant)_

| ID  | Slug | Composant | Résolu en | Date | Commit / PR | Issue GH |
|-----|------|-----------|-----------|------|-------------|----------|

---

## 🚫 Drifts `wontfix`

_(aucun)_

| ID  | Slug | Justification | ADR |
|-----|------|---------------|-----|

---

## 📌 Légende statuts

### Statut macro

- `investigating` — drift détecté, cause racine **pas encore** identifiée
- `open`          — cause racine identifiée + fix appliqué sur VM live, **pas** encore dans Packer
- `in-packer`    — fix mergé dans `packer/`, **un ou plusieurs sous-états restent à valider**
- `resolved`     — chaîne complète validée (sous-état `old-plan-deprecated` ✅)
- `wontfix`      — décision ADR explicite de ne pas propager

### Sous-états du macro `in-packer` (ADR-619 §Décision règle 3)

Un drift `in-packer` doit indiquer **quel sous-état** reste à valider — sinon le scan Qualys re-détecte indéfiniment :

| # | Sous-état              | Qui valide                | Preuve                                                       |
|---|-------------------------|---------------------------|--------------------------------------------------------------|
| 1 | `code-fixed`            | Reviewer PR               | Commit mergé sur `main`                                       |
| 2 | `image-built`           | Reviewer PR               | `az sig image-version list` montre la nouvelle version       |
| 3 | `image-submitted`       | Responsable Partner Center | Partner Center « Status: In review » (manuel UI Windows + CTT MSI) |
| 4 | `plan-live`             | Microsoft                 | Notification « Your offer is live »                            |
| 5 | `old-plan-deprecated`   | Responsable Partner Center | `endOfLifeDate` + « Stop selling » ancien plan                |

---

## 🗓️ Note historique

DRIFT-000 a été identifié à partir du **rapport Partner Center 2026-06-13**
(`docs/Certification/2026-06-13-partner.pdf`) qui re-signalait les CVE
USN-8284-1 / 8292-1 / 8293-1 / 8306-1 sur le plan `standard/6.0.20260517`
**alors même** que le fix correspondant était déjà committé dans
`packer/provisioners/01-install-base.sh` (commentaire « Cause-racine du
rejet 2026-06-02 »). Ce drift met en lumière le **pattern à risque** que ce
registre vise à éliminer :

> _Un fix présent dans `packer/` mais **pas encore matérialisé** dans une
> image gallery publiée + plan Marketplace remplacé._

C'est exactement le scénario qui motive la création de ce registre (voir
[ADR-619](../adr/619-DEVOPS-registre-drift-vm-live-vs-packer.md)).
