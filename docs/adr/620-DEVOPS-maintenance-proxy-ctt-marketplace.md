---
adr: 620
title: "Maintenance du proxy CTT — Ajustement de marketplace-ctt.sh à chaque nouveau rapport Partner Center"
status: "accepted"
date: 2026-06-14
superseded_by: null
replaces: null
related_adrs: [300, 602, 619, 700, 800, 804]
related_issues: [4]

classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "medium"
  quality:
    - "maintainability"
    - "compliance"
    - "reliability"
    - "testability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "bash"
    - "azure"
    - "vm"
    - "packer"

tags: ["ctt", "amat", "certification", "azure-marketplace", "veille", "drift", "gouvernance"]

stakeholders: ["@devops-team", "@dev-team"]

effort: "low"
---

# ADR-620 : Maintenance du proxy CTT — Ajustement de `marketplace-ctt.sh` à chaque nouveau rapport Partner Center

## 📊 Vue d'Ensemble

| Attribut                  | Valeur                                                            |
|---------------------------|-------------------------------------------------------------------|
| **Statut**                | ✅ Accepté                                                        |
| **Date Décision**         | 2026-06-14                                                        |
| **Stakeholders**          | @devops-team, @dev-team                                           |
| **Impact**                | 🟡 Moyen (qualité de la pré-validation locale, pas de production direct) |
| **Effort Implémentation** | 🟢 Faible (ajout de fonctions `test_*` à un script Bash existant) |
| **Risque Technique**      | 🟢 Faible (additif — chaque test est isolé, statistiques `PASS/WARN/FAIL` restent stables) |

---

## 🎯 Contexte & Problème

### Le rôle de `marketplace-ctt.sh`

Le script [`packer/scripts/marketplace-ctt.sh`](../../packer/scripts/marketplace-ctt.sh)
est un **proxy local** (orchestré par `make marketplace-validate`) qui exécute
sur la VM de test SMW un sous-ensemble des contrôles que Microsoft applique
dans :

- **AMAT** (Azure Marketplace Certification Tool — MSI Windows) — section 200.x
- **Scan Qualys périodique** — section 200.5.8 (CVE / USN Ubuntu)
- **Tests LISA** — sections 100.x et 200.3.3.x

Il n'a **jamais vocation** à remplacer le CTT MSI officiel (ADR-700, ADR-804),
mais il sert à :

1. **Détecter tôt** les régressions avant un build Packer + soumission Partner Center
2. **Reproduire localement** les contrôles qui ont déjà fait l'objet d'un
   rapport de certification (apprentissage explicite)
3. **Documenter** la batterie de tests sous forme exécutable (un test = une
   fonction `test_*` Bash)

### Le déclencheur — l'angle mort détecté le 2026-06-14

Au moment de l'audit de la re-notification du `2026-06-13`
(voir [DRIFT-000](../vm-live-drift/DRIFT-000-cve-patches-ubuntu-200.5.8.md))
nous avons constaté que `marketplace-ctt.sh` :

- ✅ Couvrait 16 tests (waagent, SSH, Hyper-V, TLS, DNS, kernel, swap,
  bash_history, no-default-password, LISA 200.3.3.8, …)
- ❌ **N'avait aucun test pour AMAT 200.5.8** (versions de paquets vs USN
  Ubuntu) — **précisément le test qui a causé les rapports `2026-06-02` et
  `2026-06-13`**

Conséquence : un build qui passait `make marketplace-validate` à 100 % PASS
**pouvait quand même** se faire re-notifier par Microsoft. L'angle mort venait
du fait que le script avait été conçu **avant** la première vague AMAT 200.5.8
et n'avait jamais été synchronisé avec les rapports reçus.

### Pattern à institutionnaliser

À chaque nouveau **rapport Partner Center** :

1. Si le rapport signale un **nouveau type de contrôle** (catégorie 200.x non
   encore couverte par `marketplace-ctt.sh`)
2. → Il faut **ajouter une fonction `test_<nouveau_controle>()`** au script,
   l'enregistrer dans les 3 endroits requis (cf. §Décision §3), et la
   référencer dans `show_info()` et `AVAILABLE_TESTS[]`

Sans cette discipline, le proxy diverge progressivement de la réalité
Microsoft, devient trompeur (FAUX POSITIF : « tout PASS » alors que l'image
échouera AMAT), et perd sa valeur.

### Questions Guidées

**1. Quel problème essayons-nous de résoudre ?**

- Empêcher que `marketplace-ctt.sh` devienne un **proxy obsolète** ne
  reflétant plus la batterie réelle de tests Microsoft.
- Forcer à transformer chaque rapport Partner Center reçu en **investissement
  durable** (ajout de test) plutôt qu'en correction ponctuelle d'image.

**2. Quelles sont les contraintes et exigences ?**

- **Cadence Microsoft** : ~10-15 jours entre deux scans Qualys ; les rapports
  arrivent sans préavis et changent de teneur (CVE différentes, nouveaux
  contrôles politiques).
- **Périmètre du proxy** : ne **pas** essayer de remplacer le CTT officiel
  (ADR-804) — la cible reste un *proxy* utile pour CI / pré-validation.
- **Bash + `az vm run-command`** : chaque test reste une fonction simple,
  reproductible, idempotente.
- **Cohérence ADR** : ce mécanisme s'articule avec :
  - [ADR-619](./619-DEVOPS-registre-drift-vm-live-vs-packer.md) — registre des drifts
  - [ADR-700](./700-TEST-plan-tests-integration.md) — plan de tests d'intégration
  - [ADR-804](./804-BIZ-politiques-certification-microsoft-marketplace.md) — politiques certification

**3. Quel est l'impact si nous ne prenons pas de décision ?**

- **Court terme** : autre angle mort silencieux possible à la prochaine vague
  Qualys (par ex. AMAT 200.4 GRUB params, 200.3.5 OS disk size, …).
- **Moyen terme** : `marketplace-ctt.sh` perd sa crédibilité — les
  contributeurs cessent de l'utiliser car il *ment* (PASS != cert PASS).
- **Long terme** : on revient à de la pré-validation purement manuelle, ce
  qui contredit la philosophie « Documentation as Code » du projet (ADR-700).

**4. Quels facteurs influencent cette décision ?**

- Discipline ADR + DRIFT déjà en place — on ajoute une **règle de pipeline**
  qui complète le registre.
- Les rapports Partner Center arrivent dans `docs/Certification/` avec une
  cadence connue → c'est un événement traçable.
- La structure du script `marketplace-ctt.sh` rend l'ajout d'un test trivial
  (15-25 lignes Bash + 3 enregistrements).

---

## ✅ Décision

### 1. Règle déclenchante

**À chaque rapport Partner Center qui arrive dans `docs/Certification/`**, le
contributeur qui l'ouvre **DOIT** :

1. **Lister** les sections AMAT / contrôles signalés (ex. `100.5.1.3`,
   `100.6.1`, `200.5.8`, …)
2. **Croiser** avec la liste actuelle des tests (`bash packer/scripts/marketplace-ctt.sh list`)
3. **Pour chaque section non couverte** :
   - Si le contrôle est **automatisable** depuis une VM SSH-able : ajouter une
     fonction `test_<section>()` au script
   - Si le contrôle n'est **pas automatisable** (ex. politique de listing
     `100.5.1.3` Support Link sur partner.microsoft.com) : documenter
     l'exception dans `show_info()` avec mention « contrôle manuel uniquement »

### 2. Format obligatoire d'un nouveau test

Chaque fonction `test_*()` ajoutée au script **DOIT** :

- Prendre `local vm="$1"` en argument (compatibilité avec `run_validate()`)
- Appeler `log_test "<libellé court 1 ligne>"` en début
- Exécuter les commandes via `run_on_vm "$vm" "<script Bash>"` (jamais en
  local — la cible est la VM Azure)
- Terminer par exactement un appel parmi `log_pass`, `log_fail "<message>"`,
  `log_warn "<message>"`
- Référencer l'origine (ADR / section AMAT / rapport Partner Center) en
  commentaire au-dessus de la fonction

Exemple canonique (le test ajouté le 2026-06-14, voir DRIFT-000) :

```bash
test_cve_usn() {
    local vm="$1"
    log_test "AMAT 200.5.8 — Patches CVE Ubuntu (USN-8284/8292/8293/8306)"

    # Miroir du gate Packer 01-install-base.sh §2.b
    # Source : rapports Partner Center 2026-06-02 et 2026-06-13
    # ADR-300 §9 (Test #16), ADR-619 (DRIFT-000)
    local result
    result=$(run_on_vm "$vm" "…")
    if echo "$result" | grep -qE "RESULT=0$"; then
        log_pass
    else
        log_fail "Au moins un paquet USN sous version requise"
    fi
}
```

### 3. Trois enregistrements obligatoires

Tout nouveau `test_<X>()` **DOIT** être déclaré aux **trois endroits** du
fichier (sinon `make marketplace-validate` ne l'exécutera pas) :

| # | Emplacement | Ligne (~)                                                  | Rôle                                      |
|---|-------------|------------------------------------------------------------|-------------------------------------------|
| 1 | `run_validate()` (section "Conformité Azure Marketplace" ou "Stack applicative SMW") | appel `test_<X> "$vm_name"` | Inclus dans la batterie complète |
| 2 | Tableau `AVAILABLE_TESTS=( … )`                            | `"<X>:<libellé court>"`                   | Listé par `make marketplace-tests` |
| 3 | `case "$test_name" in … esac` dans `run_single_test()`     | `<X>) test_<X> "$vm_name" ;;`             | Exécutable individuellement par `make marketplace-test TEST=<X>` |

Optionnel mais **recommandé** : ajouter une ligne dans `show_info()` (la
documentation imprimée par `make marketplace-info`).

### 4. Articulation avec DRIFT-NNN

- **Tout nouveau test ajouté** parce qu'un rapport a déclenché la révision
  **DOIT référencer la fiche DRIFT** correspondante (ou l'issue GH si pas de
  DRIFT) en commentaire de fonction.
- **Inversement**, toute fiche DRIFT créée pour un contrôle automatisable
  **DOIT** indiquer dans son §"Propagation Packer / proxy CTT" si un nouveau
  `test_*()` doit être ajouté à `marketplace-ctt.sh`.

### 5. Vérification de cohérence (acceptance check)

Avant de merger une PR qui ajoute / modifie un test dans `marketplace-ctt.sh` :

```bash
bash -n packer/scripts/marketplace-ctt.sh                           # syntaxe
bash packer/scripts/marketplace-ctt.sh list | grep <X>              # enregistrement #2
grep -c "test_<X>" packer/scripts/marketplace-ctt.sh                # >= 3 occurrences
                                                                     #   (définition + run_validate + case)
make marketplace-test TEST=<X> VM=<vm-existante>                    # exécution isolée OK
```

Ces 4 commandes peuvent être ajoutées comme cible Make `marketplace-validate-self-test`
(futur — non requis par cette ADR, mais cohérent avec ADR-602).

### Comment Cette Solution Résout le Problème

| Problème                                                       | Mécanisme de résolution                                   |
|----------------------------------------------------------------|-----------------------------------------------------------|
| Proxy CTT diverge des contrôles Microsoft réels                | Règle 1 : revue à chaque rapport, ajout systématique      |
| Test ajouté dans une seule des 3 sections (oublié dans `case`) | Règle 3 : check `grep -c` ≥ 3 occurrences avant merge     |
| Test silencieusement obsolète (versions USN figées)            | Règle 2 : commentaire de fonction cite l'ADR / le rapport |
| Pas de lien entre DRIFT et test                                | Règle 4 : référence croisée explicite                     |
| Contrôle non automatisable confondu avec un oubli              | Règle 1 §3 : exception documentée dans `show_info()`      |

### Principes Architecturaux Appliqués

- ✅ **Documentation as Code** : la batterie de tests devient un artefact
  versionné, traçable, reviewable
- ✅ **Single Source of Truth** : `marketplace-ctt.sh` reste le seul endroit
  où la batterie est définie (pas de duplication YAML / JSON)
- ✅ **Traçabilité bidirectionnelle** : test ↔ DRIFT ↔ ADR ↔ rapport Partner Center
- ✅ **Defense in depth** : ce proxy renforce le gate Packer (`01-install-base.sh`
  §2.b — voir ADR-300 §9) en ajoutant une vérification **post-build**
- ✅ **Evolvabilité** : le format `test_*()` + `AVAILABLE_TESTS[]` est conçu
  pour grandir sans refactoring (open/closed principle)

### Technologies / Outils Utilisés

| Technologie | Version | Rôle                                       |
|-------------|---------|--------------------------------------------|
| Bash 4+     | 5.x sur Ubuntu 22.04 | Format des fonctions de test  |
| `az vm run-command` | Azure CLI 2.x  | Exécution \*\*sur la VM\*\* sans dépendance SSH key |
| `dpkg-query --compare-versions` | dpkg ≥ 1.20 | Comparaison de versions Ubuntu |
| Markdown    | CommonMark | Documentation ADR + DRIFT                  |

---

## 🔄 Workflow

```text
┌─────────────────────────────────┐
│ Nouveau rapport Partner Center  │
│ docs/Certification/YYYY-MM-DD-… │
└──────────────┬──────────────────┘
               │ 1. lecture
               ▼
┌─────────────────────────────────┐
│ Liste des sections AMAT         │
│ signalées (100.x, 200.x, …)     │
└──────────────┬──────────────────┘
               │ 2. crois. avec
               │    bash marketplace-ctt.sh list
               ▼
┌─────────────────────────────────┐
│ Sections NON couvertes ?        │
└─────┬─────────────────────┬─────┘
      │ Oui                 │ Non
      ▼                     ▼
┌───────────────┐    ┌──────────────┐
│ DRIFT-NNN +   │    │ Just rebuild │
│ test_*() +    │    │ existant +   │
│ commit        │    │ submission   │
└──────┬────────┘    └──────────────┘
       │ 3. PR
       ▼
┌─────────────────────────────────┐
│ make marketplace-validate       │
│ → 17/17, 18/18, … PASS          │
└──────────────┬──────────────────┘
               │ 4. merge
               ▼
┌─────────────────────────────────┐
│ Image rebuild + Partner Center  │
│ submission (ADR-619)            │
└─────────────────────────────────┘
```

---

## 🚫 Alternatives Rejetées

| Alternative                                       | Raison du rejet                                                                          |
|---------------------------------------------------|------------------------------------------------------------------------------------------|
| **Ne rien faire** (statu quo, proxy fige)         | Cause directe de l'angle mort 200.5.8. Pattern à corriger avant qu'il se reproduise.     |
| **Tout migrer vers le CTT MSI officiel**          | Hors scope (Windows-only, non automatisable en CI Linux). Contredit ADR-602 / ADR-700.    |
| **Externaliser les tests en YAML / JSON**         | Casse le rapport coût/bénéfice : Bash + `run_on_vm` est suffisant pour ~20-30 tests. Réévaluer si > 50 tests. |
| **Générer les tests depuis le rapport PDF**       | Microsoft change le format des PDF sans préavis. Investissement disproportionné.          |
| **Outil tiers (InSpec, Goss, Lynis)**             | Lynis fait déjà partie du gate hardening (ADR-300). Ajouter un autre outil = duplication. |
| **Test inline dans `01-install-base.sh`**         | Violation séparation des responsabilités : provisioner ≠ validateur (ADR-613).            |

---

## 🔗 Articulation avec les ADR existants

| ADR liée | Articulation                                                                                                |
|----------|-------------------------------------------------------------------------------------------------------------|
| ADR-300  | Le proxy CTT **valide post-build** ce que le gate Packer §2.b vérifie **pendant le build**                  |
| ADR-602  | Le Makefile expose `marketplace-validate` / `marketplace-test` / `marketplace-tests` (ADR-602 §règle 3 lignes) |
| ADR-619  | Tout DRIFT automatisable produit une fiche **et** un nouveau `test_*()` dans le proxy                        |
| ADR-700  | Le proxy correspond à la **Phase 2** du plan de tests (image SSH-able, sans déploiement ARM complet)         |
| ADR-800  | Le proxy ne remplace **jamais** le CTT MSI obligatoire avant soumission Partner Center                       |
| ADR-804  | Cet ADR opérationnalise la veille « politiques certification » côté code — l'ADR-804 documente les politiques |

---

## 📈 Conséquences

### Positives

- **Proxy maintenu à jour** : chaque nouvelle vague AMAT enrichit la batterie
- **Effort marginal** : ajouter un test = 15-25 lignes Bash + 3 enregistrements (~10 min)
- **Réduction des faux positifs** : `marketplace-validate PASS` devient plus
  proche de « certification PASS attendue »
- **Onboarding** : un nouveau contributeur lit `marketplace-ctt.sh` = comprend
  l'historique des contrôles Microsoft applicables au projet
- **Audit-ready** : la batterie de tests = preuve écrite de discipline de
  veille certification

### Neutres

- Légère croissance du fichier `marketplace-ctt.sh` (de 16 → 17 tests
  aujourd'hui ; cible théorique ~30 tests en cas de couverture exhaustive 200.x).
  Tant que < 50 tests, monolithe Bash reste défendable. Au-delà, ré-évaluer
  une modularisation (un fichier par section AMAT).

### Négatives (risques)

- **Discipline humaine** : si un contributeur ouvre un rapport sans réviser le
  proxy, l'angle mort revient. **Mitigation** : checklist de PR + mention
  dans la description Partner Center procedure.
- **Test obsolète mais resté en place** (versions USN dépassées par
  upstream Ubuntu). **Mitigation** : commentaire de fonction cite l'USN précis ;
  un drift `wontfix` peut documenter la dépréciation explicite.
- **Faux sentiment de sécurité** : un dev pourrait croire qu'un PASS suffit à
  la soumission. **Mitigation** : `show_info()` rappelle déjà que le CTT MSI
  reste obligatoire (ADR-800 §Décision 8).

---

## ✅ Conditions de Succès / Acceptance Criteria

- [x] Premier test ajouté en application de cette ADR : `test_cve_usn()` (2026-06-14)
- [x] Format documenté avec un exemple canonique
- [x] Workflow décrit (4 étapes : lecture → croisement → ajout → merge)
- [ ] Mention dans `CONTRIBUTING.md` ou équivalent (à créer si absent)
- [ ] Au prochain rapport Partner Center reçu : appliquer la règle 1 et
      ajouter au moins un test si une nouvelle section AMAT est signalée

---

## 🔮 Conditions de revisite (déprécation possible)

Cet ADR pourra être **superseded** si l'une des conditions suivantes survient :

1. La batterie atteint > 50 tests → ré-évaluer modularisation par section AMAT
2. Adoption d'un framework dédié (InSpec, Goss) qui rendrait obsolète le
   format Bash actuel
3. Microsoft publie une **API officielle** pour interroger les contrôles
   AMAT/200.x — auquel cas le proxy peut être remplacé par un client API
4. Le projet abandonne l'offre VM (containers, AKS, …) → CTT n'est plus
   pertinent

À ce stade, créer un nouvel ADR remplaçant et passer celui-ci à
`status: superseded`.

---

## 📎 Références

- ADR-300 §9 — Test #16 : gate USN bloquant côté Packer
- ADR-602 — Makefile orchestrateur (cible `marketplace-validate`)
- ADR-619 — Registre VM-Live-Drift (DRIFT-000 a déclenché l'ajout de `test_cve_usn`)
- ADR-700 — Plan de tests d'intégration (Phase 2 = proxy CTT)
- ADR-800 — Publication Azure Marketplace (CTT MSI obligatoire avant submission)
- ADR-804 — Politiques certification Microsoft Marketplace
- Issue [#4](https://github.com/michel-heon/semantic-media-wiki-marketplace/issues/4) — Certification Marketplace (T1-T11)
- Script : [`packer/scripts/marketplace-ctt.sh`](../../packer/scripts/marketplace-ctt.sh)
- Procédure CTT MSI : [`docs/Partner/azure-ctt-procedure.md`](../Partner/azure-ctt-procedure.md)
- Rapports Partner Center : [`docs/Certification/`](../Certification/)
