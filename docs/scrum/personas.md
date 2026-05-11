# Personas — SMW Azure Marketplace

## Objet

Ce document définit les personas du projet SMW Azure Marketplace, focalisés sur la **chaîne de mise en ligne de l'offre sur Azure Marketplace**. Chaque persona représente un rôle réel de l'équipe publisher, tracé vers les processus documentés dans [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md), [ADR-617](../adr/617-DEVOPS-packer-outil-construction-images-vm.md), [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) et [ADR-603](../adr/603-DEVOPS-git-workflow-et-strategie-versioning.md).

> **P6 — Karim B.** (Validateur Sprint) a été ajouté pour couvrir le rôle de validation de fin de sprint et d'approbation du commit de fermeture, absent des 5 personas initiaux.

Ces personas servent de référence pour la rédaction des user stories, la priorisation du backlog et les critères d'acceptation.

---

## Sommaire des personas

| ID | Nom fictif | Rôle | Phase Marketplace |
|----|-----------|------|--------------------|
| [P1](#p1--thomas-r-le-devops-image-builder) | Thomas R. | DevOps — Image Builder (Packer) | Build & Compute Gallery |
| [P2](#p2--nadia-c-la-responsable-partner-center) | Nadia C. | Responsable Partner Center | Offre & publication |
| [P3](#p3--félix-m-lingénieur-certification) | Félix M. | Ingénieur Certification / Sécurité | AMAT & hardening |
| [P4](#p4--claire-b-la-rédactrice-de-listing) | Claire B. | Rédactrice de listing Marketplace | Contenu & SEO Azure |
| [P5](#p5--jérôme-v-le-product-owner-marketplace) | Jérôme V. | Product Owner — Stratégie Marketplace | Go-to-market |
| [P6](#p6--karim-b-le-validateur-sprint) | Karim B. | Validateur Sprint — QA Fonctionnel | Transversale — tous les sprints |

---

## P1 — Thomas R., le DevOps Image Builder

### Profil

| Attribut | Valeur |
|----------|--------|
| **Rôle** | DevOps Engineer — construction et publication de l'image VM |
| **Phase Marketplace** | Build Packer → Azure Compute Gallery |
| **Expérience technique** | Très élevée — Packer v1.11+, HCL2, Azure CLI, shell, Git |
| **Outils quotidiens** | VSCode, terminal, `make`, Packer, `az`, Partner Center |
| **Référence ADR** | ADR-617 (Packer), ADR-614 (itération dev VM), ADR-603 (Git), ADR-616 (cache blob) |

### Contexte

Thomas construit et maintient le pipeline de fabrication de l'image VM. Il est responsable des provisioners Packer (`01-base.sh` à `09-firstboot.sh`), du template `smw-vm.pkr.hcl` en HCL2, de la publication dans `galSMWMarketplace/smw-knowledge-base/{smw_version}.{yyyymmdd}` (convention ADR-001) et de la généralisation de l'image (`waagent -deprovision+user`). Il travaille en itérations courtes selon ADR-614 et versionne les images selon ADR-603.

### Objectifs

- Maintenir un fichier `packer/variables.pkr.hcl` comme source unique de vérité pour toutes les versions (PHP 8.2, MySQL 8.x, MediaWiki 1.43.x, SMW 6.0.1).
- Lancer un build complet et reproductible avec `make vm-build` sans intervention manuelle.
- Publier l'image versionnée dans Azure Compute Gallery avec le format `{smw_version}.{YYYYMMDD}`.
- Maintenir le temps de build maîtrisé grâce au cache APT/Composer sur Azure Blob Storage (ADR-616).
- S'assurer que chaque image généralisée passe les smoke tests avant soumission à Partner Center.

### Points de friction actuels

- Les packages APT et Composer changent upstream sans avertissement ; les versions non épinglées brisent les builds de façon intermittente.
- Le cycle build Packer complet peut dépasser 30 min sans cache ; la boucle d'itération est lente (ADR-614).
- Les erreurs de généralisation (`waagent`) sont silencieuses mais provoquent un rejet immédiat à la certification AMAT.
- La convention de nommage `{smw_version}.{YYYYMMDD}` dans la gallery doit être respectée exactement (ADR-001 §Nomenclature pipeline).

### Critères de satisfaction

- `packer validate` et `packer build` s'exécutent sans erreur sur une branche propre.
- L'image est visible dans `galSMWMarketplace` avec la version attendue.
- Le script de smoke test confirme : HTTPS actif, `Special:Version` retourne SMW 6.0.1, aucun port hors 22/443 exposé, aucun secret présent dans l'image.
- Le temps de build complet (avec cache) est inférieur à 20 min.

---

## P2 — Nadia C., la Responsable Partner Center

### Profil

| Attribut | Valeur |
|----------|--------|
| **Rôle** | Publisher Manager — gestion de l'offre dans Partner Center |
| **Phase Marketplace** | Création de l'offre → review preview → publication live |
| **Expérience technique** | Moyenne — Partner Center, Azure Portal, pas de Packer |
| **Outils quotidiens** | Partner Center (https://partner.microsoft.com), Azure Portal, email Microsoft |
| **Référence ADR** | ADR-800 (publication), ADR-001 (OFFER_ID, PUBLISHER_ID) |

### Contexte

Nadia gère la relation avec Microsoft via Partner Center. Elle est responsable de la création et la maintenance de l'offre VM (`OFFER_ID=smw-knowledge-base`, `PUBLISHER_ID=cotechnoe`), de la configuration du plan tarifaire (BYOL/Free, GPL-2.0), du ciblage de l'audience preview, et de la soumission aux cycles de certification. Elle coordonne avec Thomas pour référencer la bonne version de l'image depuis Azure Compute Gallery et avec Claire pour le contenu de listing.

Elle travaille avec la contrainte ADR-800 : le compte Partner Center et la gallery `galSMWMarketplace` doivent être dans le même tenant Entra (`aba0984a`).

### Objectifs

- Maintenir une offre VM active dans Partner Center avec un état de certification valide.
- Configurer les permissions `Compute Gallery Image Reader` sur `galSMWMarketplace` pour les Service Principals Partner Center (script `make marketplace-gallery-permissions`, ADR-800).
- Gérer le cycle de vie de chaque publication : `Draft → Preview → Live` sans blocage de certification.
- Coordonner les délais de review Microsoft (24-48h en preview, jusqu'à 7 jours en live).
- Mettre à jour le plan technique dans Partner Center à chaque nouvelle version d'image.

### Points de friction actuels

- L'erreur `"The image reference is not accessible"` dans Partner Center survient si les permissions de la gallery ne sont pas configurées avant toute publication (ADR-800 §Permissions Azure Compute Gallery).
- `OFFER_ID` est immuable après création : une erreur sur cet identifiant oblige à supprimer et recréer l'offre.
- Les cycles de review Microsoft peuvent bloquer une release imprévue ; les délais ne sont pas garantis.
- La coordination avec Thomas (image prête) et Claire (contenu listing validé) doit être synchrone avant chaque soumission.

### Critères de satisfaction

- L'offre atteint le statut `Live` sur Azure Marketplace sans rejet en certification.
- Les deux Service Principals Partner Center ont le rôle `Compute Gallery Image Reader` sur la gallery (vérifiable par `az role assignment list`, ADR-800).
- Chaque nouvelle version d'image est référencée dans le plan technique Partner Center sous 24h après le build.
- Un runbook de publication pas-à-pas est disponible dans `docs/` pour toute l'équipe.

---

## P3 — Félix M., l'Ingénieur Certification

### Profil

| Attribut | Valeur |
|----------|--------|
| **Rôle** | Ingénieur Sécurité / Validation Certification |
| **Phase Marketplace** | Hardening image → tests AMAT → remédiation |
| **Expérience technique** | Très élevée — Linux, sécurité OS, Azure Marketplace Certification Tool (AMAT) |
| **Outils quotidiens** | AMAT, `ssh`, `nmap`, `openssl`, `systemctl`, scripts de test |
| **Référence ADR** | ADR-300 (hardening, 15 tests critiques), ADR-800 §Décision 3 (tests certification Linux) |

### Contexte

Félix valide que chaque image VM respecte les 15 contrôles de certification Microsoft (AMAT — Azure Marketplace Certification Tool) avant soumission. Il exécute les tests localement sur une VM de test, remédie les non-conformités en collaboration avec Thomas (via les provisioners Packer), et signe-off l'image avant que Nadia la soumette en preview. Il s'appuie sur ADR-300 (liste exhaustive des contrôles) et ADR-800 §Décision 3 (tableau des tests).

### Tests critiques sous sa responsabilité (ADR-800 §Décision 3 / ADR-300)

| Test AMAT | Validation |
|-----------|-----------|
| `walinuxagent` installé, version récente | `apt list --installed \| grep walinuxagent` |
| `cloud-init` présent | inclus Ubuntu 22.04 LTS |
| Kernel params | `console=ttyS0 earlyprintk=ttyS0 rootdelay=300` dans `/proc/cmdline` |
| Driver réseau `hv_netvsc` | `lsmod \| grep hv_netvsc` |
| `PasswordAuthentication no` | `sshd_config` |
| `PermitRootLogin no` | `sshd_config` |
| TLS 1.2+ uniquement | `openssl s_client` sur port 443 |
| `waagent -deprovision+user -force` exécuté | image généralisée sans identifiants d'instance |

### Objectifs

- Exécuter AMAT sur chaque image candidate avant soumission Partner Center.
- Identifier et documenter tout écart par rapport aux contrôles ADR-300 dans le ticket de release.
- Valider les smoke tests post-déploiement : HTTPS actif, `Special:Version` SMW 6.0.1, ports 22 et 443 uniquement, aucun secret dans l'image.
- Maintenir un rapport de certification consultable par l'équipe.

### Points de friction actuels

- Certains tests AMAT ne produisent pas de message d'erreur explicite : le rejet de certification arrive après soumission, sans diagnostic détaillé.
- La généralisation de l'image (`waagent -deprovision`) doit être la **dernière étape** du provisioner Packer — un test prématuré peut valider une image non généralisée.
- TLS 1.2+ oblige à désactiver TLS 1.0/1.1 dans Apache — cette configuration doit survivre aux mises à jour APT.

### Critères de satisfaction

- Tous les 15 contrôles AMAT passent avant chaque soumission Partner Center (zéro rejet en preview).
- Un rapport de smoke test est produit automatiquement à chaque build (`make vm-test`).
- Les corrections de non-conformités sont tracées dans des issues Git avec référence à l'ADR concerné.

---

## P4 — Claire B., la Rédactrice de Listing Marketplace

### Profil

| Attribut | Valeur |
|----------|--------|
| **Rôle** | Technical Writer / Rédactrice de contenu Marketplace |
| **Phase Marketplace** | Offer listing — titre, description, logos, screenshots, keywords |
| **Expérience technique** | Moyenne — Markdown, rédaction technique, peu de code |
| **Outils quotidiens** | Partner Center (section Offer Listing), Figma/GIMP (visuels), Markdown |
| **Référence ADR** | ADR-801 (stratégie documentation Marketplace), ADR-800 §Décision 5 (listing content) |

### Contexte

Claire est responsable du contenu visible par les acheteurs potentiels sur Azure Marketplace. Elle rédige le titre, la description courte (256 car.), la description longue (compatible HTML), les mots-clés de découverte, les use cases et la documentation de prise en main. Elle coordonne les visuels (logo 48×48, 90×90, 216×216, 255×115 ; screenshots 1280×720) avec les contraintes Partner Center (ADR-800 §Décision 5). Elle s'appuie sur ADR-801 pour la stratégie éditoriale et ADR-001 pour les segments cibles.

### Objectifs

- Rédiger un listing Partner Center conforme aux politiques Microsoft section 100 (contenu d'offre).
- Produire une description longue qui convertit : problem statement → solution SMW → avantages Azure Marketplace → étapes de démarrage.
- Fournir les 5 formats de logo aux dimensions exactes exigées par Partner Center.
- Rédiger au moins 3 screenshots annotés montrant l'interface post-déploiement (Special:Version, Special:Ask, page principale).
- Définir les keywords de recherche Marketplace alignés avec les segments cibles ADR-001.

### Points de friction actuels

- Partner Center impose des contraintes HTML strictes sur la description longue (pas de JavaScript, pas de CSS inline non admis, longueur limitée).
- Les visuels doivent être reproductibles depuis le dépôt Git mais Partner Center ne version-contrôle pas les assets.
- La description doit être mise à jour à chaque nouvelle version majeure (SMW, MediaWiki) sans que Partner Center notifie les changements nécessaires.
- La politique Microsoft section 100 peut rejeter un listing pour des promesses de performance non vérifiables.

### Critères de satisfaction

- Le listing Partner Center passe la validation Microsoft section 100 (contenu) sans requête de correction.
- La description longue contient les versions exactes des composants (PHP 8.2, MediaWiki 1.43.x, SMW 6.0.1, Ubuntu 22.04 LTS) — anti-hallucination tracée vers ADR-001.
- Les assets visuels sont stockés dans `docs/marketplace-assets/` avec les dimensions dans le nom de fichier.
- Un checklist de mise à jour du listing est disponible pour chaque release.

---

## P5 — Jérôme V., le Product Owner Marketplace

### Profil

| Attribut | Valeur |
|----------|--------|
| **Rôle** | Product Owner — stratégie de l'offre et coordination go-to-market |
| **Phase Marketplace** | Définition de l'offre → roadmap → coordination des releases |
| **Expérience technique** | Moyenne — vision produit, Scrum, peu de code |
| **Outils quotidiens** | Partner Center (vue d'ensemble), GitHub (backlog), email, réunions de sprint |
| **Référence ADR** | ADR-001 §Plan 90 jours, ADR-800 §Vue d'ensemble, ADR-801 (documentation marketplace) |

### Contexte

Jérôme est le Product Owner de l'offre SMW Azure Marketplace. Il définit la stratégie produit (modèle BYOL/Free, GPL-2.0, ciblage PME/recherche/secteur public selon ADR-001), pilote les 3 phases du plan 90 jours (ADR-001 §Plan), priorise le backlog Scrum et coordonne les activités de certification, listing et go-to-market. Il rend compte à la direction (Cotechnoe) de l'avancement vers la publication live.

Il travaille avec 4 parties prenantes internes : Thomas (image), Nadia (Partner Center), Félix (certification), Claire (listing) — et sa responsabilité est de s'assurer que l'offre est publiée, maintenue et visible sur Azure Marketplace.

### Objectifs

- Piloter le plan 90 jours ADR-001 : Phase 1 (MVP image + certification), Phase 2 (publication preview), Phase 3 (publication live + documentation).
- Définir et maintenir le `OFFER_ID=smw-knowledge-base` et les plans tarifaires en cohérence avec ADR-800.
- Coordonner les sprints de l'équipe publisher autour des milestones de certification et de publication.
- Valider la stratégie de contenu Marketplace (ADR-801) — description, personas acheteurs, keywords.
- Gérer les communications avec Microsoft (délais de certification, refus, questions légales).

### Points de friction actuels

- Les délais de certification Microsoft sont imprévisibles (24h en preview, jusqu'à 7 jours en live) et bloquent les releases.
- La coordination entre 4 rôles techniques sur une même offre nécessite une synchronisation rigoureuse (image prête + listing validé + permissions gallery configurées = conditions de soumission).
- `OFFER_ID` immuable (ADR-800) : une erreur de nommage lors de la création de l'offre est irréversible sans recréer l'offre entièrement.
- Le plan 90 jours ADR-001 peut être perturbé par des rejets de certification non anticipés.

### Critères de satisfaction

- L'offre `smw-knowledge-base` est publiée live sur Azure Marketplace à la fin de la Phase 3 du plan 90 jours.
- Chaque sprint se termine avec un incrément mesurable : image buildée, ou listing validé, ou certification passée, ou publication live.
- Un dashboard de suivi Partner Center est partagé avec toute l'équipe.
- Le modèle économique (BYOL/Free, GPL-2.0, coût Azure seul) est documenté et validé par la direction avant publication.

---

## P6 — Karim B., le Validateur Sprint

### Profil

| Attribut | Valeur |
|----------|--------|
| **Rôle** | Validateur Sprint — QA Fonctionnel |
| **Phase Marketplace** | Transversale — tous les sprints, toutes les phases |
| **Expérience technique** | Moyenne-élevée — tests fonctionnels, checklists, lecture de logs, Git |
| **Outils quotidiens** | Terminal (`make vm-test`, smoke tests), GitHub (PR review, tags), Partner Center (lecture seule), `az CLI` |
| **Référence ADR** | ADR-603 (Git workflow — tags de fermeture sprint), ADR-300 (AMAT, smoke tests), ADR-617 (lecture rapports build) |

### Contexte

Karim est le garant de la qualité à chaque fin de sprint. Il n'écrit pas de code mais exécute les tests définis dans les Definitions of Done, relit les rapports produits par l'équipe, et approuve le commit de fermeture de sprint — un tag Git signé (ex. : `v0.3.0-epic01-done`) selon ADR-603. En cas de non-conformité d'un critère d'acceptation, il bloque la fermeture du sprint et ouvre un ticket de remédiation référençant la US et l'ADR concernés. Son seing est la condition nécessaire pour passer à l'épopée suivante ou soumettre une image à Partner Center.

Il travaille en bout de chaîne : il reçoit les livrables de Thomas (build), Félix (rapports AMAT), Nadia (Partner Center), Claire (assets listing) et Jérôme (priorisation) — et il est le dernier verrou qualité avant que chaque incrément soit déclaré « Done ».

### Objectifs

- Vérifier que chaque user story du sprint a ses critères d'acceptation satisfaits avant la sprint review.
- Exécuter ou superviser les tests de recette : `make vm-test`, smoke tests, rapports AMAT, validation des assets listing.
- Approuver le commit de fin de sprint en signant le tag Git selon ADR-603 ou en validant la PR de clôture.
- Maintenir un journal de validation par sprint (`docs/scrum/sprint-reviews/sprint-NN.md`) consultable par toute l'équipe.
- Bloquer toute soumission Partner Center (Preview ou Live) en l'absence de sign-off qualité.

### Points de friction actuels

- La validation manuelle des critères d'acceptation est chronophage si les outils de test ne sont pas automatisés (`make vm-test` doit couvrir tous les critères DoD).
- Les dépendances entre US (ex. : build Packer requis avant tests AMAT) peuvent retarder la validation de fin de sprint si les livrables arrivent en cascade.
- L'approbation du commit de fin de sprint requiert la disponibilité simultanée de plusieurs livrables : image buildée + listing validé + permissions gallery configurées.
- Un rejet Microsoft post-certification révèle une non-conformité que la validation sprint n'avait pas détectée ; Karim doit analyser la cause racine et mettre à jour la checklist DoD.

### Critères de satisfaction

- Toutes les US du sprint ont leurs critères d'acceptation vérifiés et documentés dans le journal de sprint review avant le commit de fermeture.
- Le commit de fin de sprint est tagué selon ADR-603 avec une note de validation dans le message de commit.
- Zéro US fermée sans validation explicite de P6.
- Zéro soumission Partner Center (Preview ou Live) déclenchée sans rapport de smoke test validé par P6.
- Un journal de sprint review est disponible dans `docs/scrum/sprint-reviews/` à l'issue de chaque sprint.

---

## Matrice persona × responsabilités Marketplace

| Activité | P1 Thomas (Build) | P2 Nadia (Partner Center) | P3 Félix (Certification) | P4 Claire (Listing) | P5 Jérôme (PO) | P6 Karim (QA Sprint) |
|----------|:-----------------:|:-------------------------:|:------------------------:|:-------------------:|:--------------:|:--------------------:|
| Build Packer + provisioners | **R** | — | C | — | I | I |
| Publication Azure Compute Gallery | **R** | C | — | — | I | I |
| Permissions gallery Partner Center (`make marketplace-gallery-permissions`) | C | **R** | — | — | I | I |
| Création et configuration de l'offre Partner Center | — | **R** | — | — | A | I |
| Configuration plan technique (référence image) | C | **R** | — | — | A | I |
| Tests AMAT + smoke tests | C | — | **R** | — | I | C |
| Remédiation hardening (provisioners) | **R** | — | A | — | I | I |
| Rédaction listing (titre, description, keywords) | — | — | — | **R** | A | C |
| Production assets visuels (logos, screenshots) | — | — | — | **R** | I | I |
| Soumission Preview + suivi certification | — | **R** | C | — | A | C |
| Publication Live | — | **R** | — | — | A | C |
| Roadmap et priorisation backlog | — | — | — | — | **R** | I |
| Communication Microsoft (rejets, délais) | — | C | C | — | **R** | I |
| Validation de fin de sprint (DoD sign-off) | — | — | — | — | A | **R** |

> **Légende RACI** : **R** = Responsible (exécutant), **A** = Accountable (décideur), **C** = Consulted, **I** = Informed

---

## Sources

- [ADR-001 — Définition et cadrage du projet](../adr/001-META-definition-projet-smw-marketplace.md) — stack canonique, segments cibles, plan 90 jours.
- [ADR-300 — Sécurité hardening VM certification](../adr/300-SEC-securite-hardening-vm-certification.md) — 15 contrôles AMAT, SSH hardening, TLS.
- [ADR-617 — Packer outil de construction des images VM](../adr/617-DEVOPS-packer-outil-construction-images-vm.md) — pipeline Packer, HCL2, provisioners.
- [ADR-603 — Git workflow et stratégie de versioning](../adr/603-DEVOPS-git-workflow-et-strategie-versioning.md) — conventions de branches et tags.
- [ADR-800 — Publication Azure Marketplace VM Offer](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md) — Partner Center, permissions gallery, VHD spec, certification.
- [ADR-801 — Stratégie documentation Marketplace](../adr/801-BIZ-strategie-documentation-marketplace.md) — contenu listing, keywords, assets.

