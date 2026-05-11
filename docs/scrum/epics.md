# Épopées — SMW Azure Marketplace

## Objet

Ce document identifie les **épopées nécessaires et suffisantes** pour publier SMW sur Azure Marketplace, dérivées de l'architecture cible ([smw-azure-marketplace-architecture.md](../architecture/smw-azure-marketplace-architecture.md)) et des personas publisher ([personas.md](personas.md)).

Les six épopées couvrent l'intégralité du chemin critique sans redondance. Elles respectent le plan 90 jours défini dans ADR-001 et se décomposent en user stories dans le backlog Sprint.

---

## Vue d'ensemble

| ID | Titre | Phase | Persona(s) principal(es) | Dépend de |
|----|-------|-------|--------------------------|-----------|
| [EPIC-01](#epic-01--pipeline-de-build-packer) | Pipeline de build Packer | 1 | P1 Thomas | — |
| [EPIC-02](#epic-02--runtime-client--firstboot--arm) | Runtime client — firstboot & ARM | 1 | P1 Thomas | EPIC-01 |
| [EPIC-03](#epic-03--sécurité-hardening-et-certification-amat) | Sécurité, hardening et certification AMAT | 1 | P3 Félix | EPIC-01 |
| [EPIC-04](#epic-04--offre-partner-center-et-configuration-technique) | Offre Partner Center et configuration technique | 2 | P2 Nadia, P5 Jérôme | EPIC-01, EPIC-03 |
| [EPIC-05](#epic-05--contenu-listing-et-assets-marketplace) | Contenu listing et assets Marketplace | 2 | P4 Claire, P5 Jérôme | — |
| [EPIC-06](#epic-06--publication-live-et-go-to-market) | Publication live et go-to-market | 3 | P2 Nadia, P5 Jérôme | EPIC-03, EPIC-04, EPIC-05 |

> **Phase** : 1 = MVP image + certification · 2 = Publication preview · 3 = Publication live (plan 90 jours, ADR-001)
>
> **P6 Karim** (Validateur Sprint) est impliqué dans **toutes les épopées** : il valide les critères d'acceptation de chaque US et approuve le commit de fermeture de sprint (DoD sign-off). Voir [personas.md](personas.md#p6--karim-b-le-validateur-sprint).

---

## EPIC-01 — Pipeline de build Packer

**Valeur** : En tant qu'équipe publisher, nous pouvons produire une image VM SMW versionnée, reproductible et publiée dans Azure Compute Gallery à partir d'un seul `make vm-build`.

### Périmètre

| IN | OUT |
|----|-----|
| Structure `packer/` conforme ADR-617 | Déploiement client final |
| Template `smw-vm.pkr.hcl` HCL2, plugin `hashicorp/azure ~> 2` | Configuration firstboot runtime (EPIC-02) |
| Variables centralisées `packer/variables.pkr.hcl` (PHP 8.2, MySQL 8.x, MW 1.43.x, SMW 6.0.1) | Tests AMAT (EPIC-03) |
| Provisioners shell séquentiels `01-install-base.sh` à `09-cleanup-generalize.sh` | Contenu Partner Center (EPIC-04, EPIC-05) |
| Cibles Makefile `make vm-build`, `make vm-validate` | |
| Cache APT/Composer sur Azure Blob Storage (ADR-616) | |
| Publication de l'image dans `galSMWMarketplace/smw-knowledge-base/{smw_version}.{YYYYMMDD}` | |

### User stories clés

| ID | En tant que… | Je veux… | Afin de… |
|----|-------------|----------|----------|
| US-01.1 | Thomas (P1) | un fichier `packer/variables.pkr.hcl` avec toutes les versions épinglées | éviter les régressions dues à des changements upstream |
| US-01.2 | Thomas (P1) | exécuter `make vm-validate` pour valider le template HCL2 sans build complet | détecter les erreurs de syntaxe avant de consommer du crédit Azure |
| US-01.3 | Thomas (P1) | exécuter `make vm-build` et obtenir une image dans `galSMWMarketplace` | publier une image versionnée en moins de 20 min (avec cache) |
| US-01.4 | Thomas (P1) | un cache APT/Composer sur Azure Blob Storage (ADR-616) | réduire le temps de build et éviter les pannes réseau upstream |
| US-01.5 | Thomas (P1) | un nommage `{smw_version}.{YYYYMMDD}` dans la gallery | respecter ADR-001 §Nomenclature et tracer chaque build |
| US-01.6 | Thomas (P1) | les provisioners 01-09 journalisés dans `/var/log/smw-install.log` | diagnostiquer les échecs de build sans rejouer tout le pipeline |
| US-01.7 | Karim (P6) | valider le DoD d'EPIC-01 et approuver le commit de fermeture du sprint | garantir que l'incrément Pipeline Packer est production-ready avant de démarrer EPIC-03 |

### Critères de complétion (Definition of Done)

- [ ] `packer validate` passe sur `main` sans avertissement.
- [ ] `packer build` produit une image dans `galSMWMarketplace` avec le format de version attendu.
- [ ] Le build complet (avec cache) s'effectue en moins de 20 min.
- [ ] Toutes les versions sont centralisées dans `packer/variables.pkr.hcl` — aucune version hardcodée dans les provisioners.
- [ ] `make vm-build` et `make vm-validate` sont documentées dans le README racine.
- [ ] P6 a signé-off l'incrément : tous les critères d'acceptation des US-01.1 à US-01.6 ont été vérifiés et le commit de fermeture est approuvé (ADR-603).

**ADR de référence** : [ADR-617](../adr/617-DEVOPS-packer-outil-construction-images-vm.md) · [ADR-616](../adr/616-DEVOPS-blob-storage-cache-packages-packer.md) · [ADR-614](../adr/614-DEVOPS-dev-vm-iteration-workflow.md) · [ADR-603](../adr/603-DEVOPS-git-workflow-et-strategie-versioning.md) · [ADR-001](../adr/001-META-definition-projet-smw-marketplace.md)

---

## EPIC-02 — Runtime client — firstboot & ARM

**Valeur** : En tant que client Azure, je peux déployer la VM depuis Marketplace et obtenir un wiki SMW opérationnel en HTTPS sans intervention manuelle, avec mes propres paramètres (domaine, admin, secrets).

### Périmètre

| IN | OUT |
|----|-----|
| `smw-firstboot.service` (systemd, idempotent, journalisé) | Installation des composants SMW (EPIC-01) |
| Script `firstboot.sh` : injection secrets runtime, config `LocalSettings.php`, init DB, `maintenance/update.php` | Interface Partner Center (EPIC-04) |
| `arm/mainTemplate.json` + `arm/createUIDefinition.json` | Certificat TLS définitif (responsabilité client) |
| Paramètres ARM : `adminUsername`, `wikiName`, `wikiHostName`, `wikiAdminEmail`, `wikiAdminPassword`, `databasePassword` | SSO Entra ID (ADR-302, évolution future) |
| TLS self-signed au premier boot + tentative Let's Encrypt si DNS public disponible | |
| `smw-dns-watch.timer` (optionnel) | |
| Log runtime `/var/log/smw-firstboot.log` lisible par l'opérateur | |

### User stories clés

| ID | En tant que… | Je veux… | Afin de… |
|----|-------------|----------|----------|
| US-02.1 | Client Azure | renseigner wikiName, domaine, admin et mot de passe au déploiement ARM | configurer mon wiki sans SSH post-déploiement |
| US-02.2 | Client Azure | que le wiki soit accessible en HTTPS dès la fin du premier boot | démarrer immédiatement sans intervention manuelle |
| US-02.3 | Thomas (P1) | que `smw-firstboot.service` soit idempotent | pouvoir relancer firstboot sans détruire un wiki existant |
| US-02.4 | Thomas (P1) | qu'aucun secret ne soit présent dans l'image Packer — tout injecté au runtime | respecter les exigences Marketplace (aucun credential par défaut) |
| US-02.5 | Client Azure | un log lisible `/var/log/smw-firstboot.log` | diagnostiquer un premier boot en échec sans accès console Azure |
| US-02.6 | Thomas (P1) | un workflow `make vm-dev-create` / `make provision-push` (ADR-614) | itérer sur le firstboot sans rebuild Packer complet |
| US-02.7 | Karim (P6) | valider le DoD d'EPIC-02 et approuver le commit de fermeture du sprint | garantir que le runtime firstboot est opérationnel et sécurisé avant go-to-market |

### Critères de complétion (Definition of Done)

- [ ] Une VM déployée depuis la gallery termine son firstboot sans erreur et sans intervention manuelle.
- [ ] MediaWiki est accessible en HTTPS ; `Special:Version` confirme SMW 6.0.1.
- [ ] `maintenance/update.php` s'exécute sans erreur lors du firstboot.
- [ ] `smw-firstboot.service` est idempotent : deux exécutions consécutives ne corrompent pas le wiki.
- [ ] Aucun secret (mot de passe, clé SSH de build) n'est présent dans l'image généralisée.
- [ ] `arm/mainTemplate.json` est validé par `az deployment group validate`.
- [ ] P6 a signé-off l'incrément : tous les critères d'acceptation des US-02.1 à US-02.6 ont été vérifiés et le commit de fermeture est approuvé (ADR-603).

**ADR de référence** : [ADR-617](../adr/617-DEVOPS-packer-outil-construction-images-vm.md) · [ADR-614](../adr/614-DEVOPS-dev-vm-iteration-workflow.md) · [ADR-200](../adr/200-INFRA-azure-infrastructure-vm-offer.md) · [ADR-001](../adr/001-META-definition-projet-smw-marketplace.md)

---

## EPIC-03 — Sécurité, hardening et certification AMAT

**Valeur** : En tant qu'équipe publisher, nous soumettons une image qui passe les 15 contrôles AMAT Microsoft sans rejet, et nous pouvons le démontrer avant chaque soumission Partner Center.

### Périmètre

| IN | OUT |
|----|-----|
| Provisioner `08-security-harden.sh` : SSH hardening, UFW, TLS 1.2+, permissions | Installation SMW (EPIC-01) |
| 15 contrôles AMAT : `walinuxagent`, `cloud-init`, kernel params, `hv_netvsc`, SSH policy, TLS, `waagent deprovision` | Plan tarifaire Partner Center (EPIC-04) |
| Smoke tests automatisés : HTTPS, ports exposés, `Special:Version`, absence de secrets | Contenu listing (EPIC-05) |
| Cible Makefile `make vm-test` produisant un rapport de certification consultable | |
| Kernel params obligatoires : `console=ttyS0 earlyprintk=ttyS0 rootdelay=300` | |
| `09-cleanup-generalize.sh` : nettoyage logs/clés/machine-id, `waagent -deprovision+user -force` en dernière étape | |

### User stories clés

| ID | En tant que… | Je veux… | Afin de… |
|----|-------------|----------|----------|
| US-03.1 | Félix (P3) | exécuter `make vm-test` et obtenir un rapport des 15 contrôles AMAT | signer-off l'image avant soumission Partner Center |
| US-03.2 | Félix (P3) | que `PasswordAuthentication no` et `PermitRootLogin no` soient vérifiés automatiquement | garantir le hardening SSH à chaque build sans vérification manuelle |
| US-03.3 | Félix (P3) | que TLS 1.0/1.1 soient désactivés dans Apache et que `openssl s_client` confirme TLS 1.2+ | respecter les exigences Microsoft (ADR-300) |
| US-03.4 | Félix (P3) | que `waagent -deprovision+user -force` soit la dernière étape de `09-cleanup-generalize.sh` | éviter la soumission d'une image non généralisée |
| US-03.5 | Thomas (P1) | que chaque non-conformité AMAT génère un ticket Git référençant l'ADR concerné | tracer les remédiations entre builds |
| US-03.6 | Nadia (P2) | un rapport de certification disponible avant chaque soumission Preview | confirmer la conformité avant de déclencher le cycle de review Microsoft |
| US-03.7 | Karim (P6) | valider que les 15 contrôles AMAT passent et signer-off l'image avant soumission | bloquer toute soumission Partner Center sans rapport AMAT validé par P6 |

### Critères de complétion (Definition of Done)

- [ ] Les 15 contrôles AMAT passent (zéro rejet en preview) — référence ADR-300 §Tableau des tests.
- [ ] `make vm-test` produit un rapport de certification consultable par toute l'équipe.
- [ ] Ports vérifiés : 443 (HTTPS), 80 (redirect HTTPS), 22 (restreint) — MySQL/PHP-FPM inaccessibles depuis l'extérieur.
- [ ] Aucun credential, historique bash, clé SSH de build ou journal de build présent dans l'image généralisée.
- [ ] La configuration TLS survit à un `apt upgrade` sur Apache (test de régression).
- [ ] P6 a signé-off l'incrément : le rapport `make vm-test` (15 contrôles AMAT) a été validé et le commit de fermeture est approuvé (ADR-603).

**ADR de référence** : [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) · [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md) §Décision 3

---

## EPIC-04 — Offre Partner Center et configuration technique

**Valeur** : En tant qu'équipe publisher, nous avons une offre `smw-knowledge-base` active dans Partner Center avec les permissions gallery correctement configurées, prête à référencer des images certifiées.

### Périmètre

| IN | OUT |
|----|-----|
| Création de l'offre VM dans Partner Center (`OFFER_ID=smw-knowledge-base`, `PUBLISHER_ID=cotechnoe`) | Contenu listing visible (EPIC-05) |
| Permissions `Compute Gallery Image Reader` sur `galSMWMarketplace` pour les deux Service Principals (ADR-800) | Build Packer (EPIC-01) |
| Script `make marketplace-gallery-permissions` / vérification par `az role assignment list` | |
| Configuration du plan technique : référence Compute Gallery vers version image certifiée | |
| Plan tarifaire : BYOL/Free, GPL-2.0, `Standard_D2s_v3` minimum (ADR-001) | |
| Audience preview configurée | |
| Runbook de publication pas-à-pas dans `docs/` | |

### User stories clés

| ID | En tant que… | Je veux… | Afin de… |
|----|-------------|----------|----------|
| US-04.1 | Nadia (P2) | créer l'offre `smw-knowledge-base` dans Partner Center avant toute autre étape Partner Center | éviter une erreur irréversible sur `OFFER_ID` (ADR-800) |
| US-04.2 | Nadia (P2) | exécuter `make marketplace-gallery-permissions` et vérifier par `az role assignment list` | éviter l'erreur "image reference not accessible" à la soumission |
| US-04.3 | Nadia (P2) | configurer le plan technique avec la référence de l'image certifiée depuis `galSMWMarketplace` | lier l'image buildée et certifiée à l'offre Partner Center |
| US-04.4 | Nadia (P2) | disposer d'un runbook de publication étape par étape dans `docs/` | soumettre sans dépendre d'une connaissance informelle |
| US-04.5 | Jérôme (P5) | définir le plan tarifaire BYOL/Free, GPL-2.0 dans Partner Center | respecter la stratégie commerciale ADR-001 et ADR-800 |
| US-04.6 | Nadia (P2) | configurer une audience preview restreinte avant publication publique | valider l'offre sur un déploiement réel sans exposer les acheteurs prématurément |
| US-04.7 | Karim (P6) | valider la configuration Partner Center complète et approuver le commit de fermeture | garantir que l'offre est correctement configurée avant la soumission Preview |

### Critères de complétion (Definition of Done)

- [ ] L'offre `smw-knowledge-base` existe dans Partner Center en état `Draft` ou supérieur.
- [ ] Les deux Service Principals (`497d76fa-*` et `5947d96b-*`) ont le rôle `Compute Gallery Image Reader` sur `galSMWMarketplace` (vérifiable par `az role assignment list`).
- [ ] Le plan technique référence une image certifiée dans `galSMWMarketplace`.
- [ ] L'audience preview est configurée avec au moins un compte de test.
- [ ] Un runbook de publication est disponible dans `docs/`.
- [ ] P6 a signé-off l'incrément : la configuration Partner Center et les permissions gallery ont été vérifiées et le commit de fermeture est approuvé (ADR-603).

**ADR de référence** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md) · [ADR-001](../adr/001-META-definition-projet-smw-marketplace.md)

---

## EPIC-05 — Contenu listing et assets Marketplace

**Valeur** : En tant qu'acheteur Azure, je trouve sur Marketplace un listing clair qui m'explique la valeur de SMW, me permet de décider rapidement et me guide dans le déploiement.

### Périmètre

| IN | OUT |
|----|-----|
| Titre de l'offre avec mots-clés (Semantic MediaWiki, Knowledge Base, Azure) | Code applicatif |
| Description courte (≤ 256 caractères) et description longue HTML (problème → solution → avantages → démarrage) | Configuration Partner Center technique (EPIC-04) |
| Mots-clés de recherche Marketplace alignés avec les segments cibles ADR-001 | Build Packer (EPIC-01) |
| 4 formats de logos PNG (48×48, 90×90, 216×216, 255×115) stockés dans `docs/marketplace-assets/` | |
| 3 screenshots annotés 1280×720 : accueil MediaWiki, `Special:Version` SMW, page/requête sémantique | |
| Guide post-déploiement public : configuration domaine, remplacement TLS, création admin, sauvegarde, mise à jour | |
| Checklist de mise à jour du listing pour chaque release | |
| Conformité Microsoft Certification Policy section 100 (contenu d'offre) | |

### User stories clés

| ID | En tant que… | Je veux… | Afin de… |
|----|-------------|----------|----------|
| US-05.1 | Claire (P4) | rédiger une description longue HTML conforme section 100 avec les versions exactes (ADR-001) | éviter un rejet Microsoft pour promesses non vérifiables ou versions incorrectes |
| US-05.2 | Claire (P4) | produire les 4 formats de logo PNG et les stocker dans `docs/marketplace-assets/` avec dimensions dans le nom | alimenter Partner Center et versionner les assets dans Git |
| US-05.3 | Claire (P4) | prendre 3 screenshots 1280×720 annotés depuis une VM de test déployée | montrer l'interface réelle aux acheteurs potentiels |
| US-05.4 | Claire (P4) | rédiger un guide post-déploiement public dans `docs/` | permettre aux clients de configurer leur wiki sans contacter le support |
| US-05.5 | Jérôme (P5) | valider que la description respecte ADR-801 et les segments cibles ADR-001 | aligner le listing avec la stratégie commerciale avant soumission |
| US-05.6 | Claire (P4) | une checklist de mise à jour du listing pour chaque release | maintenir le contenu Marketplace à jour sans oublier d'étape à chaque nouvelle version |
| US-05.7 | Karim (P6) | valider les assets et le contenu listing et approuver le commit de fermeture | garantir que le listing est conforme Microsoft section 100 avant soumission Preview |

### Critères de complétion (Definition of Done)

- [ ] Le listing passe la validation Microsoft section 100 sans requête de correction.
- [ ] La description longue contient les versions exactes (PHP 8.2, MediaWiki 1.43.x, SMW 6.0.1, Ubuntu 22.04 LTS) — anti-hallucination tracée vers ADR-001.
- [ ] Les 4 formats de logo sont dans `docs/marketplace-assets/` avec les dimensions dans le nom de fichier.
- [ ] 3 screenshots 1280×720 annotés sont produits et soumis dans Partner Center.
- [ ] Un guide post-déploiement est disponible publiquement dans `docs/`.
- [ ] Une checklist de mise à jour du listing est disponible pour l'équipe.
- [ ] P6 a signé-off l'incrément : le contenu listing (description, versions canoniques, assets) a été vérifié et le commit de fermeture est approuvé (ADR-603).

**ADR de référence** : [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md) · [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md) §Décision 5 · [ADR-001](../adr/001-META-definition-projet-smw-marketplace.md)

---

## EPIC-06 — Publication live et go-to-market

**Valeur** : En tant qu'équipe publisher, l'offre `smw-knowledge-base` est publiée Live sur Azure Marketplace, le suivi d'acquisition est en place et l'équipe peut gérer les rejets de certification sans bloquer les releases suivantes.

### Périmètre

| IN | OUT |
|----|-----|
| Soumission Preview avec audience restreinte et validation complète | Build de nouvelles versions (cycle suivant) |
| Smoke tests post-déploiement sur VM déployée depuis Preview | Refonte des personas ou de la stratégie |
| Soumission Live après validation Preview | |
| Suivi et gestion des délais certification Microsoft (24-48h preview, jusqu'à 7j live) | |
| URLs de campagne avec `ocid`/`utm_*` pour les actions marketing (ADR-801 §GTM) | |
| Dashboard Partner Center partagé avec l'équipe (vues, clics, déploiements) | |
| Runbook de gestion des rejets et communications Microsoft | |

### User stories clés

| ID | En tant que… | Je veux… | Afin de… |
|----|-------------|----------|----------|
| US-06.1 | Nadia (P2) | soumettre l'offre en Preview et valider le déploiement complet depuis Partner Center | confirmer l'expérience client réelle avant publication publique |
| US-06.2 | Félix (P3) | exécuter les smoke tests sur la VM déployée depuis l'audience Preview | signer-off la qualité avant de déclencher la soumission Live |
| US-06.3 | Nadia (P2) | soumettre l'offre en Live après validation Preview complète | rendre l'offre visible sur Azure Marketplace pour tous les acheteurs |
| US-06.4 | Jérôme (P5) | un dashboard Partner Center partagé avec l'équipe | mesurer la traction après publication (vues, clics, déploiements) |
| US-06.5 | Jérôme (P5) | des URLs de campagne `ocid`/`utm_*` pour les actions marketing | attribuer les conversions Marketplace aux canaux promotionnels |
| US-06.6 | Jérôme (P5) | un runbook de gestion des rejets et des délais Microsoft | réagir rapidement sans bloquer la release en cas de rejet Microsoft |
| US-06.7 | Karim (P6) | signer-off la publication Live et valider le go-to-market complet | clôturer officiellement le plan 90 jours ADR-001 avec un incrément conforme |

### Critères de complétion (Definition of Done)

- [ ] L'offre atteint le statut `Live` sur Azure Marketplace.
- [ ] Un déploiement complet depuis Marketplace (audience publique) fonctionne sans intervention manuelle.
- [ ] `Special:Version` confirme SMW 6.0.1 sur la VM déployée en production.
- [ ] Le dashboard Partner Center est accessible à toute l'équipe.
- [ ] Les URLs de campagne sont définies et documentées dans `docs/`.
- [ ] Le runbook de gestion des rejets est disponible dans `docs/`.
- [ ] P6 a signé-off l'incrément final : l'offre Live, le dashboard Partner Center et les URLs de campagne ont été vérifiés ; le commit de clôture du projet est approuvé (ADR-603).

**ADR de référence** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md) · [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md) · [ADR-001](../adr/001-META-definition-projet-smw-marketplace.md) §Plan 90 jours Phase 3

---

## Matrice épopées × personas

| Épopée | P1 Thomas (Build) | P2 Nadia (Partner Center) | P3 Félix (Certification) | P4 Claire (Listing) | P5 Jérôme (PO) | P6 Karim (QA Sprint) |
|--------|:-----------------:|:-------------------------:|:------------------------:|:-------------------:|:--------------:|:--------------------:|
| EPIC-01 Pipeline Packer | **Lead** | — | Reviewer | — | Sponsor | **Validateur** |
| EPIC-02 Runtime firstboot + ARM | **Lead** | — | Reviewer | — | Sponsor | **Validateur** |
| EPIC-03 Sécurité & certification AMAT | Contributeur | Bénéficiaire | **Lead** | — | Sponsor | **Validateur** |
| EPIC-04 Offre Partner Center | — | **Lead** | — | — | Co-lead | **Validateur** |
| EPIC-05 Contenu listing & assets | — | Reviewer | — | **Lead** | Reviewer | **Validateur** |
| EPIC-06 Publication live & GTM | Contributeur | **Lead** | Reviewer | Contributeur | Co-lead | **Validateur** |

> Aligné avec la matrice RACI de [personas.md](personas.md).

---

## Ordre d'exécution recommandé (plan 90 jours ADR-001)

```
Phase 1 — Semaines 1-6 (MVP + certification)
  EPIC-01  Pipeline Packer                  ← semaine 1 (socle bloquant)
  EPIC-02  Runtime firstboot + ARM          ← en parallèle avec EPIC-01, semaines 2-4
  EPIC-03  Sécurité & AMAT                  ← après EPIC-01 (provisioners en place), semaines 3-6
  EPIC-05  Contenu listing & assets         ← en parallèle dès semaine 2 (indépendant du build)

Phase 2 — Semaines 7-10 (Preview)
  EPIC-04  Offre Partner Center             ← après EPIC-01 + EPIC-03 (image certifiée disponible)
  Finalisation EPIC-05

Phase 3 — Semaines 11-13 (Live + GTM)
  EPIC-06  Publication live & GTM           ← après EPIC-03 + EPIC-04 + EPIC-05
```

---

## Sources

- [personas.md](personas.md) — 6 personas publisher (P1–P6) et matrice RACI — dont P6 Karim (Validateur Sprint).
- [smw-azure-marketplace-architecture.md](../architecture/smw-azure-marketplace-architecture.md) — architecture cible, backlog technique (§12), Definition of Done architecture (§13).
- [ADR-001](../adr/001-META-definition-projet-smw-marketplace.md) — plan 90 jours, stack canonique, segments cibles.
- [ADR-200](../adr/200-INFRA-azure-infrastructure-vm-offer.md) — infrastructure Azure, VM sizing.
- [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) — 15 contrôles AMAT, SSH hardening, TLS.
- [ADR-603](../adr/603-DEVOPS-git-workflow-et-strategie-versioning.md) — conventions de branches et tags.
- [ADR-614](../adr/614-DEVOPS-dev-vm-iteration-workflow.md) — workflow d'itération rapide VM.
- [ADR-616](../adr/616-DEVOPS-blob-storage-cache-packages-packer.md) — cache APT/Composer Azure Blob.
- [ADR-617](../adr/617-DEVOPS-packer-outil-construction-images-vm.md) — pipeline Packer, HCL2, provisioners.
- [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md) — Partner Center, permissions gallery, cycle publication.
- [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md) — stratégie contenu Marketplace, GTM.
