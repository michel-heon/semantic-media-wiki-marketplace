---
adr: 619
title: "Registre des Drifts VM Live ↔ Packer — Traçabilité des Hotfix à Propager"
status: "accepted"
date: 2026-06-14
superseded_by: null
replaces: null
related_adrs: [300, 602, 603, 607, 613, 700, 804]
related_issues: [4]

classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "medium"
  quality:
    - "maintainability"
    - "traceability"
    - "compliance"
    - "reliability"
  reversibility: "moderate"
  scope: "tactical"
  tech_areas:
    - "packer"
    - "azure"
    - "vm"
    - "bash"

tags: ["drift", "packer", "traceability", "hotfix", "certification", "azure-marketplace", "gouvernance"]

stakeholders: ["@dev-team", "@architecture-team", "@devops-team"]

effort: "low"
---

# ADR 619 : Registre des Drifts VM Live ↔ Packer — Traçabilité des Hotfix à Propager

## 📊 Vue d'Ensemble

| Attribut                  | Valeur                                                            |
|---------------------------|-------------------------------------------------------------------|
| **Statut**                | ✅ Accepté                                                        |
| **Date Décision**         | 2026-06-14                                                        |
| **Stakeholders**          | @dev-team, @architecture-team, @devops-team                       |
| **Impact**                | 🟡 Moyen (gouvernance — pas de code production direct)            |
| **Effort Implémentation** | 🟢 Faible (dossier markdown + références)                         |
| **Risque Technique**      | 🟢 Faible (additif, n'altère pas le pipeline existant)            |

---

## 🎯 Contexte & Problème

### Le déclencheur — Rapport Partner Center du 2026-06-13

Le **2026-06-13**, **Microsoft Partner Center** signale, via le rapport
`docs/Certification/2026-06-13-partner.pdf`, **4 vulnérabilités CVSS3 ≥ 8.5**
(USN-8284-1 / 8292-1 / 8293-1 / 8306-1) sur le plan publié
`standard/6.0.20260517` (test AMAT 200.5.8). L'enquête révèle un problème
**non technique mais organisationnel** :

> Le fix correspondant — gate USN dans
> [`packer/provisioners/01-install-base.sh`](../../packer/provisioners/01-install-base.sh)
> §2.b — **est déjà committé** dans le repo (voir le commentaire « Cause-racine
> du rejet de certification du 2026-06-02 : USN-8284-1, USN-8292-1, USN-8293-1,
> USN-8306-1 »). Pourtant le plan `standard/6.0.20260517` **reste publié et
> vulnérable** parce qu'aucune image neuve n'a été buildée + soumise depuis ce
> fix.

Aucun mécanisme ne signale cet écart à la personne qui builde la prochaine
image, ni au responsable de la soumission Partner Center.

### Pattern récurrent observé

Le rapport `docs/Certification/2026-06-02-partner.pdf` signalait déjà
exactement les mêmes 4 USN. Onze jours plus tard, le rapport `2026-06-13`
re-signale les **mêmes** CVE sur la **même** version (`6.0.20260517`). Cela
révèle une **séquence défaillante** :

```
[problème détecté sur plan / VM live]
       ↓
[fix urgent (a) appliqué manuellement, OU (b) committé dans Packer]
       ↓
[ ? aucun pont systématique entre fix et prochaine image publiée ? ]
       ↓
[nouvelle image jamais buildée OU buildée mais non publiée OU plan vulnérable
 non déprécié → certification continue d'échouer]
```

Cas concrets recensés :

| Cas                            | Détection                              | État avant ADR-619                                          |
|--------------------------------|----------------------------------------|-------------------------------------------------------------|
| CVE Ubuntu 200.5.8 (USN-8284, 8292, 8293, 8306) | Rapport Partner Center 2026-06-02 puis 2026-06-13 | Fix mergé dans `01-install-base.sh` mais plan `6.0.20260517` toujours vulnérable |
| Re-injection `authorized_keys` par waagent | Validation T-CERT-01 sur `dev-smw-20260608` | Comportement compris (mémoire repo) mais aucun drift formel |
| Faux positif sudo dans auth.log | Tests `vm-security-check.sh`           | Solution documentée empiriquement, non rattachée à un drift |

### Questions Guidées

**1. Quel problème essayons-nous de résoudre ?**

- Garantir que **toute correction appliquée à une VM live OU mergée dans
  Packer** (hotfix SSH, patch de configuration, fix d'un smoke test) **soit
  matérialisée dans une image publiée gallery** avant qu'un plan vulnérable
  ne subisse une moderation action Microsoft (retrait possible).
- Fournir une **mémoire institutionnelle** survivant aux personnes : à chaque
  nouvelle vague de certification (cadence Qualys ~30–60 jours), la pratique
  de remédiation doit être immédiatement retrouvable.

**2. Quelles sont les contraintes et exigences ?**

- **Techniques** : compatible avec l'arbo `docs/adr/` existante, formats
  markdown reviewable en PR, indexable par un agent IA (frontmatter YAML —
  cf. ADR-002 et TAXONOMY.md).
- **Azure Marketplace** : la cadence de scan Qualys impose un cycle de
  remédiation rapide (échéance Microsoft `8/27/2026` pour le rapport
  2026-06-13). Sans traçabilité formelle, le délai n'est pas tenable.
- **Open Source** : aucune dépendance à un outil propriétaire de drift
  detection (Terraform Cloud, AWS Config). Pure markdown + git.
- **Équipe** : taille réduite. Le mécanisme doit être léger, sans gouvernance
  lourde.

**3. Quel est l'impact si nous ne prenons pas de décision ?**

- **Court terme (0-3 mois)** : risque concret de **moderation action**
  Microsoft sur le plan `6.0.20260517` après l'échéance `8/27/2026`. Risque de
  livrer une image `6.0.20260YYY` qui intègre les fix CVE mais omet d'autres
  fix déjà committés (ex. drift `authorized_keys`).
- **Moyen terme (3-12 mois)** : à chaque nouvelle vague AMAT, perte de
  productivité (redécouverte de drifts déjà identifiés mais oubliés).
- **Long terme (12+ mois)** : le projet devient dépendant de la mémoire d'un
  individu. Bus factor élevé. Difficulté à onboarder un contributeur externe
  ou à reprendre le projet après une période d'inactivité.

**4. Quels facteurs influencent cette décision ?**

- Discipline ADR déjà en place — on ajoute un mécanisme **complémentaire**,
  pas un substitut.
- Issues GitHub utilisées (ex. #4 — Certification Marketplace T1-T11) mais
  elles **disparaissent** quand fermées et ne donnent pas vue d'ensemble
  multi-incidents.
- Pas de budget pour outils SaaS de drift detection ni pour automatisation CI
  avancée.

---

## ✅ Décision

### Approche Choisie

Nous instaurons un **registre de drifts** dans `docs/vm-live-drift/`,
structuré comme suit :

```
docs/vm-live-drift/
├── README.md                 ← procédure + workflow + statuts
├── REGISTRY.md               ← tableau central (1 ligne = 1 drift)
├── 000-template.md           ← gabarit obligatoire pour nouvelle entrée
├── DRIFT-000-<slug>.md       ← fiche détaillée par drift
├── DRIFT-001-<slug>.md
└── ...
```

**Règles fondamentales** :

1. **Tout écart constaté** entre une image SMW VM (dev / gallery / Marketplace)
   et ce que le code `packer/` est censé produire **DOIT** faire l'objet d'une
   fiche `DRIFT-NNN-<slug>.md` et d'une ligne dans `REGISTRY.md`.
2. **Toute PR qui modifie `packer/provisioners/`, `packer/scripts/` ou
   `packer/smw-vm.pkr.hcl`** en réponse à un incident VM live (ou rapport
   Partner Center) **DOIT** référencer la fiche DRIFT correspondante dans son
   message de commit ou son corps de PR.
3. Le **cycle de vie** d'un drift est explicite et **granulaire** : la
   chaîne de remédiation Marketplace comporte **5 sous-états** qui doivent
   être tracés indépendamment (leçon de l'audit du rapport `2026-06-13` —
   voir [DRIFT-000](../vm-live-drift/DRIFT-000-cve-patches-ubuntu-200.5.8.md)).

   | Statut macro     | Sous-état              | Qui le valide              | Preuve attendue                                           |
   |------------------|-------------------------|----------------------------|-----------------------------------------------------------|
   | `investigating`  | —                       | Auteur du drift            | Fiche `DRIFT-NNN.md` créée avec symptôme + reproduction   |
   | `open`           | —                       | Auteur du drift            | Cause racine identifiée + hotfix VM live reproductible    |
   | `in-packer`      | `code-fixed`            | Reviewer PR                | Commit fix mergé sur `main`                                |
   | `in-packer`      | `image-built`           | Reviewer PR                | `az sig image-version list` montre la nouvelle version    |
   | `in-packer`      | `image-submitted`       | Responsable Partner Center | Screenshot Partner Center → « Status: In review »          |
   | `in-packer`      | `plan-live`             | Microsoft                  | Notification Partner Center « Your offer is live »         |
   | `resolved`       | `old-plan-deprecated`   | Responsable Partner Center | `endOfLifeDate` non null + « Stop selling » ancien plan   |
   | `wontfix`        | —                       | Décision explicite         | Justification dans la fiche + ADR référencé               |

   **Pourquoi cette granularité ?** L'audit du rapport `2026-06-13` a démontré
   que les 3 sous-états `image-submitted` / `plan-live` / `old-plan-deprecated`
   sont des **actions manuelles** côté Partner Center (UI Windows) qui ne sont
   **pas automatisables** depuis le repo Linux. Un drift bloqué sur l'un de
   ces sous-états reste `in-packer` mais doit clairement indiquer **lequel**
   sous-état est en attente — sinon le scan Qualys re-détecte les mêmes CVE
   indéfiniment.

4. Un drift `resolved` (sous-état `old-plan-deprecated` validé) reste dans le
   registre comme **archive pédagogique** — il sert de cas d'école pour la
   prochaine vague de certification.

### Comment Cette Solution Résout le Problème

| Problème                                                   | Mécanisme de résolution                                         |
|------------------------------------------------------------|-----------------------------------------------------------------|
| Fix mergé dans repo mais image en retard                   | Statut `in-packer` rend l'écart visible jusqu'au rebuild        |
| Plan publié vulnérable malgré fix dans repo                | DRIFT distingue explicitement « code corrigé » de « image publiée + plan remplacé » |
| Fix appliqué SSH-en-direct et oublié                       | Obligation de fiche `DRIFT-NNN.md` avec hotfix reproductible    |
| Comportement empirique non documenté (waagent, sudo log)   | Champ « Cause racine » + « Reproduction » formalise la découverte |
| Nouveau contributeur ne connaît pas la pratique            | `README.md` racine pointe ADR-619 + procédure                   |
| Vague AMAT future                                          | Lecture du registre = panorama complet de la dette technique    |
| Audit Microsoft sur la discipline de patch                 | REGISTRY.md = preuve d'audit trail                              |

### Principes Architecturaux Appliqués

- ✅ **Traçabilité bidirectionnelle** : chaque drift relie VM live ↔ commit
  Packer ↔ ADR ↔ issue GH ↔ smoke test ↔ rapport Partner Center
- ✅ **Reproductibilité** : la fiche DRIFT contient les commandes SSH /
  `dpkg-query` exactes pour rejouer le diagnostic et le hotfix
- ✅ **Open Source compliance** : aucune dépendance à un outil
  propriétaire ; pure markdown + git
- ✅ **Documentation as Code** : registres versionnés, reviewable en PR,
  greppable
- ✅ **AI-friendly** : structure prévisible (template fixe + frontmatter
  cohérent — ADR-002) → un agent IA peut lister, classer et corréler les drifts
- ✅ **Defense in depth (ADR-300)** : ce mécanisme renforce le pilier
  « vérification déterministe » en ajoutant une couche **organisationnelle**
  par-dessus les couches techniques (assertions provisioners, gate Test #16,
  validation Packer ADR-613)

### Technologies / Outils Utilisés

| Technologie | Version | Rôle                              | Justification                          |
|-------------|---------|-----------------------------------|----------------------------------------|
| Markdown    | CommonMark | Format des fiches               | Reviewable PR, lisible CLI et web      |
| Git         | ≥ 2.30  | Versioning des fiches             | Historique, blame, bisect              |
| GitHub Issues | -     | Lien social vers le registre      | Notification, assignation, milestones  |
| _(aucune dépendance d'outillage spécifique)_ |  |  |                                |

---

## 🔄 Workflow

```text
┌──────────────────┐    1. détection           ┌────────────────────┐
│ Smoke test ÉCHEC │ ────────────────────────► │ Fix manuel sur VM  │
│ (vm-security-    │   (test ID, package,      │   (apt, ssh,       │
│  check / AMAT /  │    version attendue)      │    sed, systemctl) │
│  Partner Center) │                           │                    │
└──────────────────┘                           └──────────┬─────────┘
                                                          │ 2. fix validé
                                                          ▼
┌──────────────────────┐  4. propagation     ┌────────────────────────┐
│ Image Packer rebuild │ ◄────────────────── │ DRIFT-NNN-<slug>.md    │
│ (smw-vm.pkr.hcl +    │   (PR + commit)     │ + entrée REGISTRY.md   │
│  bump IMAGE_VERSION) │                     └──────────┬─────────────┘
└──────────┬───────────┘                                │ 3. doc
           │                                            │
           │ 5. verify                                  ▼
           ▼                                  ┌───────────────────────┐
┌──────────────────┐                          │ ADR mise à jour si    │
│ Smoke test PASS  │ ◄────────────────────────│ décision nouvelle     │
│  sur image neuve │                          │ (ex. ADR-300 §Test #N)│
└──────────────────┘                          └───────────────────────┘
```

Procédure détaillée dans
[`docs/vm-live-drift/README.md`](../vm-live-drift/README.md).

---

## 🚫 Alternatives Rejetées

| Alternative                          | Raison du rejet                                                                                   |
|--------------------------------------|---------------------------------------------------------------------------------------------------|
| **Issues GitHub seules**             | Disparaissent à la fermeture. Pas de vue d'ensemble multi-incidents. Pas de template structuré.   |
| **Un nouvel ADR par drift**          | Dilue la valeur des ADR (décisions architecturales rares — ADR-000). Un drift est un **incident**, pas une décision. |
| **Section dans `CHANGELOG.md`**      | Orienté livraisons, pas écarts. Ne capture pas l'état « fix dans repo mais image en retard ».     |
| **TODO inline dans le code Packer**  | Invisible côté gouvernance. Aucun lien avec ADR / certification. Disparaît au reformatage.        |
| **Wiki GitHub**                      | Hors `git` → désynchronisation possible. Pas reviewable en PR.                                    |
| **Mémoire repo (`/memories/repo/`)** | Excellente pour les découvertes empiriques (waagent, sudo log) — complémentaire mais **pas un substitut** : pas visible côté revue PR ni Partner Center. |
| **Outil tiers (Terraform drift, AWS Config)** | Hors scope du projet (Packer + Azure VM gallery, pas Terraform). Coût + complexité non justifiés. |
| **Statu quo (mémoire individuelle)** | Bus factor élevé. Incompatible avec la cadence de certification Microsoft.                       |

---

## 🔗 Articulation avec les ADR existants

| ADR liée | Articulation                                                                                       |
|----------|----------------------------------------------------------------------------------------------------|
| ADR-300  | Le registre **opérationnalise** la veille hardening : tout écart aux tests doit générer un DRIFT  |
| ADR-602  | Le Makefile peut exposer une cible `make drift-registry-check` (futur) consultant le REGISTRY      |
| ADR-603  | Les tags git de release référencent les DRIFT résolus dans la version concernée                    |
| ADR-607  | La procédure version-bump consulte le REGISTRY pour décider si le bump est `patch` ou `minor`      |
| ADR-613  | Architecture des provisioners — chaque DRIFT cible un provisioner précis (`01-install-base.sh` …) |
| ADR-700  | Les tests d'intégration (phase 2 / 3) sont la **source principale de détection** de nouveaux drifts |
| ADR-804  | Section « politique certification » — le registre = outil de mise en œuvre opérationnel           |

---

## 📈 Conséquences

### Positives

- **Mémoire institutionnelle** robuste aux changements de personnes
- **Cadence de remédiation** Microsoft tenable même en cas de multi-CVE
  simultanées
- **Onboarding** : un nouveau contributeur lit ADR-619 + REGISTRY = comprend
  la dette technique en < 30 min
- **Audit-ready** : REGISTRY constitue une preuve de discipline lors d'un
  audit Microsoft / SOC / ISO
- **Cohérence ADR** : aucun ADR existant n'est invalidé ; le mécanisme
  s'ajoute en complément
- **Distinction explicite** entre « code corrigé » (`in-packer`) et « image
  publiée + plan remplacé » (`resolved`) — précisément le gap qui a causé la
  re-notification du 2026-06-13

### Neutres

- Ajoute une **étape légère** au workflow de fix (rédiger la fiche). Compensée
  par le temps économisé à ne pas redécouvrir un bug 6 mois plus tard.

### Négatives (risques)

- Discipline humaine : si un contributeur ignore la règle et patche
  directement Packer sans entrée DRIFT, le registre devient partiel.
  **Mitigation** : règle de review PR + mention dans un futur `CONTRIBUTING.md`.
- Risque de **duplication** avec les issues GitHub si la frontière n'est pas
  claire. **Mitigation** : règle énoncée explicitement — issues = file
  d'attente sociale, registre = journal technique structuré ; les deux se
  référencent.
- Le registre peut **enfler** dans le temps si jamais nettoyé. **Mitigation** :
  les drifts `resolved` peuvent être archivés en sous-dossier
  `docs/vm-live-drift/archive/` après 1 an (à décider dans un futur ADR si le
  besoin se confirme).

---

## ✅ Conditions de Succès / Acceptance Criteria

- [x] Dossier `docs/vm-live-drift/` créé avec README, REGISTRY, template
- [x] Au moins 1 drift documenté à titre d'exemple (DRIFT-000 CVE)
- [x] Référence dans ADR-300 (section « Suivi des écarts VM live ↔ Packer »)
- [ ] Mention dans la documentation racine (à créer)
- [ ] Prochain rebuild image : DRIFT-000 passe `in-packer` → `resolved` (preuve
      que le pipeline consulte le registre)
- [ ] Plan `standard/6.0.20260517` déprécié dans Partner Center avant 2026-08-27

---

## 🔮 Conditions de revisite (déprécation possible)

Cet ADR pourra être **superseded** si l'une des conditions suivantes survient :

1. Adoption d'un outil automatisé de drift detection (Packer + Terraform +
   périodique CI) qui rendrait obsolète le suivi manuel
2. Réduction du périmètre à une seule image VM rebuilt automatiquement à
   chaque commit (CI/CD nightly) — auquel cas le drift n'a plus le temps
   d'apparaître
3. Migration vers une distribution non-Packer (containers immutables, AKS, …)
   qui changerait fondamentalement le modèle

À ce stade, créer un nouvel ADR remplaçant et passer celui-ci à
`status: superseded`.

---

## 📎 Références

- ADR-300 : Hardening VM — défense en profondeur + Test #16 (gate USN)
- ADR-602 : Makefile orchestrateur
- ADR-603 : Git workflow et stratégie versioning
- ADR-607 : Procédure version-bump (source canonique `env/.env.dev`)
- ADR-613 : Architecture et validation des provisioners Packer
- ADR-700 : Plan de tests d'intégration (phase 1 / 2 / 3)
- ADR-804 : Politiques certification Microsoft Marketplace
- Issue [#4](https://github.com/michel-heon/semantic-media-wiki-marketplace/issues/4) — Certification Marketplace (T1-T11)
- Rapport `docs/Certification/2026-06-13-partner.pdf` (déclencheur)
- Rapport `docs/Certification/2026-06-02-partner.pdf` (première notification mêmes CVE)
- Registre : [`docs/vm-live-drift/README.md`](../vm-live-drift/README.md), [`docs/vm-live-drift/REGISTRY.md`](../vm-live-drift/REGISTRY.md)
