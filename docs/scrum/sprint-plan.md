# Plan de sprints — SMW Azure Marketplace

**Objet** : Planification des 6 sprints de 2 semaines couvrant les 42 récits utilisateur issus des 6 épopées.  
Chaque sprint correspond à une épopée, se termine par la validation DoD de P6 Karim (US-X.7) et produit un incrément livrable.  
**Références** : [epics.md](epics.md) · [user-stories.md](user-stories.md) · [personas.md](personas.md) · ADR-001 (plan 90 jours) · ADR-603 (versioning Git)

**Versions canoniques (ADR-001 — ne jamais inventer d'autres numéros)** :  
Ubuntu 22.04 LTS · PHP 8.2-FPM · MySQL 8.x · MediaWiki 1.43.x · SMW 6.0.1 · Apache 2.4 · Packer 1.11+

---

## Calendrier global

| Sprint | Épopée | Dates | Objectif principal | Phase |
|--------|--------|-------|--------------------|-------|
| [S1](#sprint-1--pipeline-de-build-packer) | EPIC-01 | 2026-05-11 → 2026-05-24 | Pipeline Packer opérationnel, image dans la gallery | 1 — MVP image |
| [S2](#sprint-2--runtime-client--firstboot--arm) | EPIC-02 | 2026-05-25 → 2026-06-07 | VM auto-configurée HTTPS au premier boot | 1 — MVP image |
| [S3](#sprint-3--sécurité-hardening-et-certification-amat) | EPIC-03 | 2026-06-08 → 2026-06-21 | Image certifiable — 15 contrôles AMAT passés | 1 — MVP image |
| [S4](#sprint-4--offre-partner-center-et-configuration-technique) | EPIC-04 | 2026-06-22 → 2026-07-05 | Offre Partner Center créée, plan Preview soumis | 2 — Preview |
| [S5](#sprint-5--contenu-listing-et-assets-marketplace) | EPIC-05 | 2026-07-06 → 2026-07-19 | Listing complet validé par le PO | 2 — Preview |
| [S6](#sprint-6--publication-live-et-go-to-market) | EPIC-06 | 2026-07-20 → 2026-08-02 | Offre Live sur Azure Marketplace | 3 — Go Live |

> **Durée totale** : 13 semaines ≈ 90 jours, conforme au plan ADR-001.  
> **Capacité cible** : 7 US par sprint (6 US core + 1 US validation P6 Karim).  
> **Fermeture de sprint** : chaque sprint est fermé par le commit tagué après sign-off de P6 (ADR-603).

---

## Dépendances inter-sprints

```
S1 (EPIC-01 — Packer)
  ├── S2 (EPIC-02 — Firstboot)       ← dépend de S1
  └── S3 (EPIC-03 — AMAT)            ← dépend de S1
        └── S4 (EPIC-04 — Partner Center) ← dépend de S1 + S3
              └── S6 (EPIC-06 — Live)    ← dépend de S3 + S4 + S5

S5 (EPIC-05 — Listing/Assets)        ← INDÉPENDANT (peut démarrer à tout moment)
  └── S6 (EPIC-06 — Live)            ← dépend de S5
```

> **Conséquence** : les Sprints 1, 2 et 3 forment le chemin critique. S5 peut démarrer en parallèle de S2/S3 si la capacité d'équipe le permet (P4 Claire et P5 Jérôme ne sont pas bloqués par S1).

---

## Sprint 1 — Pipeline de build Packer

| Attribut | Valeur |
|----------|--------|
| **Épopée** | EPIC-01 |
| **Dates** | 2026-05-11 → 2026-05-24 (2 semaines) |
| **Objectif** | Disposer d'un `make vm-build` qui produit une image versionnée dans `galSMWMarketplace` de manière reproductible en moins de 20 min (avec cache Blob). |
| **Persona principal** | P1 Thomas R. (DevOps Image Builder) |
| **Validateur fin de sprint** | P6 Karim B. (sign-off DoD, US-01.7) |

### Backlog du sprint

| ID | Titre | Persona | Priorité | Statut |
|----|-------|---------|----------|--------|
| US-01.1 | Variables Packer centralisées (`packer/variables.pkr.hcl`) | P1 Thomas | Must | ☐ |
| US-01.2 | Validation HCL2 sans build (`make vm-validate`) | P1 Thomas | Must | ☐ |
| US-01.3 | Build et publication dans `galSMWMarketplace` | P1 Thomas | Must | ☐ |
| US-01.4 | Cache APT/Composer sur Azure Blob Storage (ADR-616) | P1 Thomas | Must | ☐ |
| US-01.5 | Nommage versionné `{smw_version}.{YYYYMMDD}` dans la gallery | P1 Thomas | Must | ☐ |
| US-01.6 | Journalisation provisioners dans `/var/log/smw-install.log` | P1 Thomas | Must | ☐ |
| US-01.7 | **Validation DoD EPIC-01 — sign-off P6** | P6 Karim | Must | ☐ |

### Cérémonies

| Cérémonie | Moment | Participants |
|-----------|--------|--------------|
| Sprint Planning | 2026-05-11 | P1 Thomas, P5 Jérôme (PO), P6 Karim |
| Daily Scrum | Chaque jour ouvrable | P1 Thomas |
| Sprint Review | 2026-05-23 | P1 Thomas, P5 Jérôme, P6 Karim |
| Sprint Retrospective | 2026-05-24 | Équipe complète |

### Critères de complétion (Definition of Done)

- [ ] `packer validate` passe sans avertissement sur `main`.
- [ ] `packer build` produit une image dans `galSMWMarketplace` au format `{smw_version}.{YYYYMMDD}`.
- [ ] Build complet ≤ 20 min avec cache Blob Storage.
- [ ] Aucune version hardcodée dans les provisioners `01-*.sh` à `09-*.sh`.
- [ ] `make vm-build` et `make vm-validate` documentées dans le README racine.
- [ ] **P6 Karim a signé-off l'incrément** — commit de fermeture de sprint tagué `v0.2.0-epic01-packer-pipeline` (ADR-603).

### Risques sprint

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Premier build long sans cache | Élevée | Prioriser US-01.4 (cache Blob) en jour 1-3 |
| Quota Azure dépassé pendant build | Faible | Utiliser `Standard_D2s_v3` comme spécifié ADR-617 |
| Plugin `hashicorp/azure ~> 2` incompatible | Faible | Pin explicite dans `smw-vm.pkr.hcl` dès US-01.1 |

**ADR de référence** : ADR-617 · ADR-616 · ADR-614 · ADR-603 · ADR-001

---

## Sprint 2 — Runtime client — firstboot & ARM

| Attribut | Valeur |
|----------|--------|
| **Épopée** | EPIC-02 |
| **Dates** | 2026-05-25 → 2026-06-07 (2 semaines) |
| **Objectif** | Un client qui déploie la VM depuis Marketplace obtient un wiki SMW opérationnel en HTTPS sans intervention manuelle. |
| **Persona principal** | P1 Thomas R. (DevOps Image Builder) |
| **Validateur fin de sprint** | P6 Karim B. (sign-off DoD, US-02.7) |
| **Prérequis** | Sprint 1 fermé — image disponible dans `galSMWMarketplace` |

### Backlog du sprint

| ID | Titre | Persona | Priorité | Statut |
|----|-------|---------|----------|--------|
| US-02.1 | Paramètres ARM injectés au déploiement (`mainTemplate.json`) | P1 Thomas | Must | ☐ |
| US-02.2 | Wiki HTTPS opérationnel au premier boot | Client | Must | ☐ |
| US-02.3 | Idempotence `smw-firstboot.service` (rejouer sans corruption) | P1 Thomas | Must | ☐ |
| US-02.4 | Aucun secret dans l'image (injection runtime uniquement) | P1 Thomas | Must | ☐ |
| US-02.5 | Log firstboot lisible par le client (`journalctl -u smw-firstboot`) | Client | Should | ☐ |
| US-02.6 | Workflow itération rapide dev (ADR-614) | P1 Thomas | Should | ☐ |
| US-02.7 | **Validation DoD EPIC-02 — sign-off P6** | P6 Karim | Must | ☐ |

### Cérémonies

| Cérémonie | Moment | Participants |
|-----------|--------|--------------|
| Sprint Planning | 2026-05-25 | P1 Thomas, P5 Jérôme (PO), P6 Karim |
| Daily Scrum | Chaque jour ouvrable | P1 Thomas |
| Sprint Review | 2026-06-06 | P1 Thomas, P5 Jérôme, P6 Karim |
| Sprint Retrospective | 2026-06-07 | Équipe complète |

### Critères de complétion (Definition of Done)

- [ ] `arm/mainTemplate.json` et `arm/createUIDefinition.json` validés par `az deployment validate`.
- [ ] `smw-firstboot.service` idempotent — rejouer deux fois sans erreur ni corruption DB.
- [ ] Aucun secret (mot de passe DB, clé API) présent dans l'image Packer.
- [ ] Wiki accessible en HTTPS sur le port 443 après premier boot, `maintenance/update.php` exécuté avec succès.
- [ ] **P6 Karim a signé-off l'incrément** — commit tagué `v0.3.0-epic02-firstboot-arm` (ADR-603).

> **Note** : US-02.5 et US-02.6 sont "Should" — reportables à S3 si la capacité est insuffisante.

### Risques sprint

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Injection secrets ARM échoue au runtime | Moyenne | Tester avec `az deployment group create` dès US-02.1 |
| TLS auto-signé bloqué par le navigateur client | Faible | Documenter procédure d'exception et prévoir Let's Encrypt hook |
| `firstboot.service` non-idempotent sur maintenance/update.php | Moyenne | Ajouter flag sentinel `/var/lib/smw/.firstboot-done` |

**ADR de référence** : ADR-617 · ADR-614 · ADR-302 · ADR-603 · ADR-001

---

## Sprint 3 — Sécurité, hardening et certification AMAT

| Attribut | Valeur |
|----------|--------|
| **Épopée** | EPIC-03 |
| **Dates** | 2026-06-08 → 2026-06-21 (2 semaines) |
| **Objectif** | L'image passe les 15 contrôles AMAT Microsoft sans rejets bloquants ; un rapport de conformité est produit pour Nadia (P2) avant soumission Partner Center. |
| **Persona principal** | P3 Félix M. (Ingénieur Certification / Sécurité) |
| **Validateur fin de sprint** | P6 Karim B. (sign-off DoD, US-03.7) |
| **Prérequis** | Sprint 1 fermé — image disponible dans `galSMWMarketplace` |

### Backlog du sprint

| ID | Titre | Persona | Priorité | Statut |
|----|-------|---------|----------|--------|
| US-03.1 | Rapport 15 contrôles AMAT (Certification Test Tool) | P3 Félix | Must | ☐ |
| US-03.2 | Hardening SSH automatisé (`PasswordAuthentication no`, port 22 NSG) | P3 Félix | Must | ☐ |
| US-03.3 | TLS 1.2+ vérifié par tests automatisés | P3 Félix | Must | ☐ |
| US-03.4 | `waagent -deprovision+user -force` dernière étape provisioner | P3 Félix | Must | ☐ |
| US-03.5 | Traçabilité non-conformités AMAT → tickets correctives | P1 Thomas | Should | ☐ |
| US-03.6 | Rapport certif livré à P2 Nadia avant Preview | P2 Nadia | Must | ☐ |
| US-03.7 | **Validation DoD EPIC-03 — sign-off P6** | P6 Karim | Must | ☐ |

### Cérémonies

| Cérémonie | Moment | Participants |
|-----------|--------|--------------|
| Sprint Planning | 2026-06-08 | P3 Félix, P1 Thomas, P5 Jérôme (PO), P6 Karim |
| Daily Scrum | Chaque jour ouvrable | P3 Félix, P1 Thomas |
| Sprint Review | 2026-06-20 | P3 Félix, P2 Nadia, P5 Jérôme, P6 Karim |
| Sprint Retrospective | 2026-06-21 | Équipe complète |

### Critères de complétion (Definition of Done)

- [ ] Certification Test Tool (AMAT) : 0 erreur bloquante, ≤ 2 warnings non-bloquants documentés.
- [ ] `PasswordAuthentication no` dans `/etc/ssh/sshd_config` vérifiée par test automatisé.
- [ ] TLS 1.2+ uniquement — TLS 1.0 et 1.1 désactivés dans Apache config.
- [ ] `waagent -deprovision+user -force` exécuté en dernière étape de `09-cleanup-generalize.sh` sans étape ultérieure.
- [ ] Rapport AMAT livré à P2 Nadia en format PDF/Markdown avant fin de sprint.
- [ ] **P6 Karim a signé-off l'incrément** — commit tagué `v0.4.0-epic03-security-amat` (ADR-603).

### Risques sprint

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Rejet AMAT — bash history non nettoyé | Élevée | Inclure `history -c && rm -f ~/.bash_history` dans `09-cleanup` |
| Rejet AMAT — root login SSH activé | Moyenne | `PermitRootLogin no` dans `02-install-base.sh` |
| TLS auto-signé flag AMAT warning | Faible | Documenter comme attendu, prévoir Let's Encrypt au firstboot |

**ADR de référence** : ADR-300 · ADR-300b · ADR-617 · ADR-603 · ADR-800

---

## Sprint 4 — Offre Partner Center et configuration technique

| Attribut | Valeur |
|----------|--------|
| **Épopée** | EPIC-04 |
| **Dates** | 2026-06-22 → 2026-07-05 (2 semaines) |
| **Objectif** | L'offre `smw-knowledge-base` est créée dans Partner Center avec le plan technique lié à l'image certifiée ; une Preview audience restreinte peut déployer la VM. |
| **Persona principal** | P2 Nadia C. (Responsable Partner Center) |
| **Persona secondaire** | P5 Jérôme V. (PO — plan tarifaire) |
| **Validateur fin de sprint** | P6 Karim B. (sign-off DoD, US-04.7) |
| **Prérequis** | Sprint 1 (image gallery) + Sprint 3 (certification AMAT) fermés |

### Backlog du sprint

| ID | Titre | Persona | Priorité | Statut |
|----|-------|---------|----------|--------|
| US-04.1 | Création offre Partner Center (`OFFER_ID=smw-knowledge-base`, publisher `cotechnoe`) | P2 Nadia | Must | ☐ |
| US-04.2 | Permissions gallery — SP `497d76fa` + `5947d96b` en `Compute Gallery Image Reader` | P2 Nadia | Must | ☐ |
| US-04.3 | Plan technique lié à l'image certifiée dans `galSMWMarketplace` | P2 Nadia | Must | ☐ |
| US-04.4 | Runbook publication pas-à-pas (procédure reproductible) | P2 Nadia | Must | ☐ |
| US-04.5 | Plan tarifaire BYOL / Free GPL-2.0 défini et validé | P5 Jérôme | Must | ☐ |
| US-04.6 | Audience Preview restreinte configurée (tenant `aba0984a`) | P2 Nadia | Must | ☐ |
| US-04.7 | **Validation DoD EPIC-04 — sign-off P6** | P6 Karim | Must | ☐ |

### Cérémonies

| Cérémonie | Moment | Participants |
|-----------|--------|--------------|
| Sprint Planning | 2026-06-22 | P2 Nadia, P5 Jérôme (PO), P6 Karim |
| Daily Scrum | Chaque jour ouvrable | P2 Nadia |
| Sprint Review | 2026-07-04 | P2 Nadia, P5 Jérôme, P6 Karim |
| Sprint Retrospective | 2026-07-05 | Équipe complète |

### Critères de complétion (Definition of Done)

- [ ] Offre `smw-knowledge-base` créée sous publisher `cotechnoe` dans Partner Center (tenant `aba0984a`).
- [ ] Les deux SPs (`497d76fa-f477-478a-aa29-49b0dee35030`, `5947d96b-019a-46ba-ad4b-8ffc6f493b2e`) ont le rôle `Compute Gallery Image Reader` sur `galSMWMarketplace`.
- [ ] Plan VM technique lié à l'image certifiée — `make marketplace-gallery-permissions` documenté et fonctionnel.
- [ ] Preview audience restreinte configurée — test de déploiement par un membre de l'audience Preview réussi.
- [ ] Plan tarifaire BYOL documenté dans Partner Center + fichier `docs/marketplace/pricing.md`.
- [ ] **P6 Karim a signé-off l'incrément** — commit tagué `v0.5.0-epic04-partner-center` (ADR-603).

### Risques sprint

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Misalignment tenant gallery ≠ Partner Center | Élevée | Vérifier `aba0984a` dès US-04.1 (ADR-001 §Risques) |
| Permissions SP refusées par Azure RBAC | Moyenne | Script `az role assignment create` dans `make marketplace-gallery-permissions` |
| Rejet Microsoft à la soumission Preview | Faible | S'appuyer sur rapport AMAT de S3 |

**ADR de référence** : ADR-800 · ADR-603 · ADR-001 · ADR-300

---

## Sprint 5 — Contenu listing et assets Marketplace

| Attribut | Valeur |
|----------|--------|
| **Épopée** | EPIC-05 |
| **Dates** | 2026-07-06 → 2026-07-19 (2 semaines) |
| **Objectif** | Le listing Marketplace est complet — description HTML conforme, 4 logos PNG, 3 screenshots annotés, guide post-déploiement — validé par P5 Jérôme avant soumission Live. |
| **Persona principal** | P4 Claire B. (Rédactrice listing Marketplace) |
| **Persona secondaire** | P5 Jérôme V. (PO — validation listing) |
| **Validateur fin de sprint** | P6 Karim B. (sign-off DoD, US-05.7) |
| **Prérequis** | Indépendant techniquement — peut démarrer dès S1 si la capacité le permet ; **obligatoire avant S6** |

### Backlog du sprint

| ID | Titre | Persona | Priorité | Statut |
|----|-------|---------|----------|--------|
| US-05.1 | Description longue HTML conforme aux guidelines Marketplace | P4 Claire | Must | ☐ |
| US-05.2 | 4 logos PNG aux formats requis (48×48, 90×90, 115×115, 255×115) | P4 Claire | Must | ☐ |
| US-05.3 | 3 screenshots 1280×720 annotés (déploiement, wiki, SMW) | P4 Claire | Must | ☐ |
| US-05.4 | Guide post-déploiement public (`docs/marketplace/getting-started.md`) | P4 Claire | Must | ☐ |
| US-05.5 | Validation listing complet par P5 Jérôme (PO sign-off) | P5 Jérôme | Must | ☐ |
| US-05.6 | Checklist mise à jour listing lors de chaque bump de version | P5 Jérôme | Should | ☐ |
| US-05.7 | **Validation DoD EPIC-05 — sign-off P6** | P6 Karim | Must | ☐ |

### Cérémonies

| Cérémonie | Moment | Participants |
|-----------|--------|--------------|
| Sprint Planning | 2026-07-06 | P4 Claire, P5 Jérôme (PO), P6 Karim |
| Daily Scrum | Chaque jour ouvrable | P4 Claire, P5 Jérôme |
| Sprint Review | 2026-07-18 | P4 Claire, P5 Jérôme, P6 Karim |
| Sprint Retrospective | 2026-07-19 | Équipe complète |

### Critères de complétion (Definition of Done)

- [ ] Description HTML validée par l'outil Partner Center (< 3 000 mots, pas de HTML interdit).
- [ ] 4 fichiers logo PNG présents dans `docs/marketplace/assets/logos/` aux dimensions exactes requises.
- [ ] 3 screenshots 1280×720 annotés présents dans `docs/marketplace/assets/screenshots/`.
- [ ] Guide post-déploiement disponible publiquement (lien dans la description Partner Center).
- [ ] P5 Jérôme a approuvé le listing (US-05.5 fermée).
- [ ] **P6 Karim a signé-off l'incrément** — commit tagué `v0.6.0-epic05-listing-assets` (ADR-603).

### Risques sprint

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Assets visuels non conformes aux specs Microsoft | Moyenne | Consulter guidelines Marketplace dès US-05.2 |
| Contenu HTML rejeté (balises interdites) | Faible | Utiliser le validator Partner Center avant upload |
| Guide post-déploiement obsolète vs firstboot ARM | Faible | P4 Claire collabore avec P1 Thomas pour relecture technique |

**ADR de référence** : ADR-800 · ADR-801 · ADR-603

---

## Sprint 6 — Publication live et go-to-market

| Attribut | Valeur |
|----------|--------|
| **Épopée** | EPIC-06 |
| **Dates** | 2026-07-20 → 2026-08-02 (2 semaines) |
| **Objectif** | L'offre `smw-knowledge-base` est Live sur Azure Marketplace — Preview validée, soumission Live approuvée par Microsoft, dashboard GTM opérationnel. |
| **Persona principal** | P2 Nadia C. (Responsable Partner Center) |
| **Persona secondaire** | P1 Thomas R. (smoke tests VM Preview), P5 Jérôme V. (GTM) |
| **Validateur fin de sprint** | P6 Karim B. (sign-off DoD final — US-06.7) |
| **Prérequis** | Sprint 3 (AMAT) + Sprint 4 (Partner Center) + Sprint 5 (listing) fermés |

### Backlog du sprint

| ID | Titre | Persona | Priorité | Statut |
|----|-------|---------|----------|--------|
| US-06.1 | Soumission Preview et validation Microsoft (audience restreinte) | P2 Nadia | Must | ☐ |
| US-06.2 | Smoke tests VM Preview (`make vm-smoke-test`) | P1 Thomas | Must | ☐ |
| US-06.3 | Soumission Live et go-live approuvé par Microsoft | P2 Nadia | Must | ☐ |
| US-06.4 | Dashboard Partner Center partagé avec l'équipe (accès lecture) | P5 Jérôme | Should | ☐ |
| US-06.5 | URLs campagne `?ocid=` / `utm_*` définies pour le GTM | P5 Jérôme | Should | ☐ |
| US-06.6 | Runbook gestion des rejets Microsoft (procédure corrective) | P2 Nadia | Must | ☐ |
| US-06.7 | **Validation DoD EPIC-06 — sign-off P6 (clôture projet)** | P6 Karim | Must | ☐ |

### Cérémonies

| Cérémonie | Moment | Participants |
|-----------|--------|--------------|
| Sprint Planning | 2026-07-20 | P2 Nadia, P1 Thomas, P5 Jérôme (PO), P6 Karim |
| Daily Scrum | Chaque jour ouvrable | P2 Nadia, P1 Thomas |
| Sprint Review | 2026-08-01 | Équipe complète |
| Sprint Retrospective + Clôture projet | 2026-08-02 | Équipe complète |

### Critères de complétion (Definition of Done)

- [ ] Preview audience restreinte a pu déployer la VM et valider le wiki SMW.
- [ ] `make vm-smoke-test` passe : HTTPS, MediaWiki login, SMW query, port 22 accessible par clé, port 3306 fermé externe.
- [ ] Offre Live approuvée par Microsoft et visible sur `azuremarketplace.microsoft.com`.
- [ ] Runbook rejets documenté dans `docs/marketplace/rejection-runbook.md`.
- [ ] **P6 Karim a signé-off la clôture du projet** — commit tagué `v1.0.0-go-live` (ADR-603).

> **Note** : US-06.4 et US-06.5 sont "Should" — reportables post-go-live sans impact sur la publication.

### Risques sprint

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Rejet Microsoft en Preview (bash history, TLS) | Moyenne | Rapport AMAT S3 est le filet de sécurité |
| Délai de review Microsoft > 2 semaines | Élevée | Soumettre Preview en début de S6 pour maximiser le temps de review |
| Smoke tests échouent sur VM Preview | Faible | Tests identiques à ceux de S3 — régression peu probable si image inchangée |

**ADR de référence** : ADR-800 · ADR-603 · ADR-001 · ADR-301

---

## Matrice US × Sprints

| Sprint | US Must | US Should | Total US | Personas actifs |
|--------|---------|-----------|----------|-----------------|
| S1 — EPIC-01 | 7 | 0 | **7** | P1 Thomas, P6 Karim |
| S2 — EPIC-02 | 5 | 2 | **7** | P1 Thomas, P6 Karim |
| S3 — EPIC-03 | 6 | 1 | **7** | P3 Félix, P1 Thomas, P2 Nadia, P6 Karim |
| S4 — EPIC-04 | 7 | 0 | **7** | P2 Nadia, P5 Jérôme, P6 Karim |
| S5 — EPIC-05 | 6 | 1 | **7** | P4 Claire, P5 Jérôme, P6 Karim |
| S6 — EPIC-06 | 5 | 2 | **7** | P2 Nadia, P1 Thomas, P5 Jérôme, P6 Karim |
| **Total** | **36** | **6** | **42** | |

> Les 6 US "Should" (US-02.5, US-02.6, US-03.5, US-05.6, US-06.4, US-06.5) peuvent être reportées sans bloquer la publication si la capacité est contrainte.
