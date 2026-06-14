# 📋 VM Live Drift Registry — smw-marketplace

Registre des **écarts (drift)** détectés entre l'image SMW VM **en production /
test live** (Azure Compute Gallery / Marketplace) et le code source **Packer**
dans ce repo. Chaque entrée trace une correction appliquée à chaud sur une VM
live (ou détectée via un rapport Partner Center / AMAT) qui **doit être
propagée** dans `packer/provisioners/` ou `packer/scripts/` pour qu'une
**prochaine image** soit conforme.

> **Décision fondatrice** : [ADR-619](../adr/619-DEVOPS-registre-drift-vm-live-vs-packer.md)
> **ADR liées** : ADR-200, ADR-300, ADR-602, ADR-607, ADR-613, ADR-700, ADR-804

---

## 🎯 Objectif

Garantir la **traçabilité bidirectionnelle** entre :

- 🖥️  **Live VM / Image gallery** (résultat smoke tests, AMAT 200.5.8, CTT,
  certification Partner Center, support utilisateur)
- 📦  **Packer source** (image golden reproductible — `smw-vm.pkr.hcl` +
  `packer/provisioners/`)
- 📐  **ADR** (décisions architecturales)

Sans ce registre, une correction appliquée sur la VM live ou un fix mergé dans
Packer **avant** la dernière image publiée est **invisible** : la prochaine
image peut réintroduire le bug, ou pire — laisser un plan vulnérable en place
(ex. plan `standard/6.0.20260517` resté vulnérable malgré un fix mergé dans
`01-install-base.sh`).

---

## 📂 Structure

```
docs/vm-live-drift/
├── README.md                 ← ce fichier
├── REGISTRY.md               ← tableau central (1 ligne = 1 drift)
├── 000-template.md           ← gabarit pour nouvelle entrée
├── DRIFT-000-...md           ← description détaillée drift #0
├── DRIFT-001-...md
└── ...
```

---

## 🔄 Workflow

```
┌──────────────────┐    1. détection           ┌────────────────────┐
│ Smoke test ÉCHEC │ ────────────────────────► │ Fix manuel sur VM  │
│ (vm-security-    │   (test ID, package,      │   (curl, ssh,      │
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

---

## 📝 Procédure (quand un smoke test échoue sur VM live ou un rapport Partner Center signale un écart)

### Étape 1 — Reproduire et corriger sur la VM
```bash
# Exemple : version paquet en retard (CVE Qualys)
ssh azureuser@$VM_IP "dpkg-query -W -f='\${Package}\t\${Version}\n' libgnutls30 libarchive13 bind9-host bind9-libs libwbclient0"

# Si écart constaté → patcher la VM :
ssh azureuser@$VM_IP "sudo apt-get update && sudo apt-get -y -o Dpkg::Options::='--force-confold' dist-upgrade"

# Relancer le check pour confirmer le fix
make vm-security-check VM_IP=$VM_IP
```

### Étape 2 — Allouer un numéro de drift
Numérotation séquentielle : `DRIFT-000`, `DRIFT-001`, `DRIFT-002`, … Voir
`REGISTRY.md` pour le prochain numéro libre.

### Étape 3 — Créer `DRIFT-NNN-<slug>.md`
Copier `000-template.md` puis remplir :
- Symptôme observé (test ID, header HTTP, log, sortie commande, rapport Partner Center)
- Cause racine (provisioner manquant, fix mergé après build, dérive upstream Ubuntu, etc.)
- Correction appliquée sur VM (commandes exactes — reproductibles)
- Fichier(s) Packer à modifier pour propager
- ADR à mettre à jour (si applicable)

### Étape 4 — Propager dans Packer
Modifier le(s) provisioner(s) concernés :
- `packer/provisioners/01-install-base.sh` (apt upgrade, USN gate, kernel, locales)
- `packer/provisioners/02-install-php.sh` (PHP 8.2 + extensions)
- `packer/provisioners/03-install-apache.sh` (Apache + TLS)
- `packer/provisioners/04-install-mysql.sh` (MySQL bind-address)
- `packer/provisioners/05-install-mediawiki.sh`
- `packer/provisioners/06-install-smw.sh`
- `packer/provisioners/07-security-harden.sh` (UFW, SSH, fail2ban, auditd)
- `packer/provisioners/08-firstboot-setup.sh`
- `packer/provisioners/09-cleanup-generalize.sh`

### Étape 5 — Rebuild + bump version
Suivre **ADR-607** (procédure version-bump) :
```bash
# 1. Éditer la source canonique
$EDITOR env/.env.dev        # bumper IMAGE_VERSION (6.0.YYYYMMDD)

# 2. Régénérer les fichiers générés + ARM
make setup                  # bootstrap.sh
make arm-build              # bicep → mainTemplate.json

# 3. Build + publication
make packer-build
make gallery-publish

# 4. Tag git aligné (ADR-603 §7)
git tag -a v6.0.YYYYMMDD-drift-NNN-<slug> -m "..."
```

### Étape 6 — Vérifier
Déployer une VM depuis la nouvelle image, lancer la suite intégration
(ADR-700 phase 2 / phase 3). Marquer le drift **`status: resolved`** dans
`REGISTRY.md` avec la version qui le corrige.

---

## 🏷️ Statuts possibles

| Statut          | Signification                                                        |
|-----------------|----------------------------------------------------------------------|
| `investigating` | Drift détecté, cause racine **pas encore** identifiée                |
| `open`          | Cause racine identifiée + fix appliqué sur VM live, **pas** encore propagé Packer |
| `in-packer`    | Fix mergé dans `packer/`, image rebuild **pas encore** publiée gallery |
| `resolved`      | Image publiée + smoke test PASS sur image neuve + plan vulnérable déprécié |
| `wontfix`      | Décision explicite (justifiée dans la fiche + ADR) de ne pas propager |

---

## 🔗 Liens

- [REGISTRY.md](./REGISTRY.md) — tableau des drifts
- [000-template.md](./000-template.md) — gabarit
- [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) — hardening + Test #16 (gate USN)
- [ADR-602](../adr/602-DEVOPS-makefile-orchestrateur.md) — orchestration Make
- [ADR-607](../adr/607-DEVOPS-procedure-version-bump.md) — procédure version-bump
- [ADR-613](../adr/613-DEVOPS-provisioner-architecture-validation.md) — architecture provisioners
- [ADR-619](../adr/619-DEVOPS-registre-drift-vm-live-vs-packer.md) — décision fondatrice
- [ADR-700](../adr/700-TEST-plan-tests-integration.md) — plan de tests d'intégration
- [ADR-804](../adr/804-BIZ-politiques-certification-microsoft-marketplace.md) — politiques certification

## 📌 Issues GitHub liées

| Issue                                                                                          | Statut  | Relation au registre                                              |
|------------------------------------------------------------------------------------------------|---------|-------------------------------------------------------------------|
| [#4](https://github.com/michel-heon/semantic-media-wiki-marketplace/issues/4) — Certification Marketplace (T1-T11) | open    | Cadre général — chaque test produit des drifts potentiels         |
