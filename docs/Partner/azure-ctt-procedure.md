# Azure Certification Test Tool (CTT) — Procédure d'exécution

## Contexte

L'outil officiel **Azure Certification Test Tool (CTT)** est un MSI Windows
fourni par Microsoft pour valider qu'une image VM Linux/Windows respecte les
politiques 200.x (VM offer) avant soumission Partner Center.

**Référence officielle** : https://aka.ms/azurecertificationtesttool
**ADR associé** : [ADR-804](../adr/804-BIZ-politiques-certification-microsoft-marketplace.md)
**Issue** : [#4](https://github.com/michel-heon/semantic-media-wiki-marketplace/issues/4) — T8

---

## 1. Quand exécuter CTT

| Étape | Préalable | CTT requis ? |
|-------|-----------|--------------|
| Build Packer + Phase 1 (static) | Repo synchronisé | ❌ Non |
| Phase 2 (image SSH) — `marketplace-ctt.sh` maison | VM dev déployée | ⚪ Optionnel (proxy) |
| **Avant soumission Partner Center** | VHD/Gallery image publiée | ✅ **OBLIGATOIRE** |
| Resubmission après rejet | Image patchée | ✅ Re-exécuter |

> **Notre proxy automatisable** : `make marketplace-validate` exécute
> `packer/scripts/marketplace-ctt.sh` — un sous-ensemble des contrôles CTT,
> automatisable en CI. **Ne remplace pas** le CTT officiel pour la
> soumission Partner Center.

---

## 2. Prérequis CTT MSI (Windows)

| Élément | Valeur |
|---------|--------|
| **OS hôte** | Windows 10 / 11 / Server 2019+ |
| **PowerShell** | 5.1+ ou PowerShell Core 7+ |
| **SSH client** | OpenSSH (intégré Windows 10+ ou Git Bash) |
| **Connectivité** | Internet sortant + SSH (22/tcp) vers la VM cible |
| **Privilèges** | Admin local pour installer le MSI |

> **Si vous travaillez sous Linux/macOS** : provisionnez une VM Windows
> jetable (ex: `Standard_B2ms` Windows Server 2022) dans `rg-smw-dev-michel`
> pour héberger le CTT.

---

## 3. Préparation de la VM cible

### 3.1 Déployer la VM depuis la Gallery image

```bash
# Recréer la VM dev avec la dernière image certifiée
make vm-dev-create
# Sortie attendue : VM dev-smw-<YYYYMMDD> @ <PUBLIC_IP>
```

### 3.2 Vérifier l'accessibilité SSH

```bash
ssh -o StrictHostKeyChecking=no azureuser@<PUBLIC_IP> "uname -a; uptime"
```

Attendu : kernel `6.8.0-1052-azure` (ou ultérieur), uptime > 30 s.

### 3.3 Valider Phase 2 (notre proxy maison)

```bash
E2E_RG=rg-smw-dev-michel VM_NAME=dev-smw-<YYYYMMDD> ADMIN_USERNAME=azureuser \
    make integration-test-image
```

Attendu : **26/26 PASS** (10 T-IMAGE + 16 T-CERT). Si KO → corriger avant CTT.

---

## 4. Installation et exécution du CTT officiel

### 4.1 Télécharger le MSI

Sur la machine Windows :

```powershell
# Ouvrir un navigateur et télécharger depuis :
Start-Process "https://aka.ms/azurecertificationtesttool"

# Ou via PowerShell direct (vérifier le lien actuel) :
Invoke-WebRequest -Uri "https://aka.ms/azurecertificationtesttool" `
                  -OutFile "$env:USERPROFILE\Downloads\CertificationTestTool.msi"
```

### 4.2 Installer le MSI

```powershell
Start-Process msiexec.exe -ArgumentList "/i $env:USERPROFILE\Downloads\CertificationTestTool.msi /qb" -Wait
```

Par défaut installé sous `C:\Program Files\Azure Certification Test Tool\`.

### 4.3 Lancer le CTT

Démarrer **Azure Certification Test Tool** depuis le menu Démarrer.

### 4.4 Configuration de la cible (Linux VM)

| Champ | Valeur pour SMW |
|-------|-----------------|
| **OS** | Linux |
| **Hostname / IP** | `<PUBLIC_IP>` de la VM dev-smw |
| **Port SSH** | `22` |
| **Authentication** | SSH key (clé privée Azure user) |
| **Username** | `azureuser` |
| **Private key path** | `C:\Users\<vous>\.ssh\azure_smw_dev` (clé copiée depuis `~/.ssh/`) |
| **Sudo password** | Vide (azureuser dispose de NOPASSWD via cloud-init) |

> **Sécurité** : ne copier la clé privée que temporairement sur le poste Windows.
> Supprimer après l'exécution du CTT (`Remove-Item $env:USERPROFILE\.ssh\azure_smw_dev`).

### 4.5 Sélection des tests

CTT propose 3 modes :

| Mode | Couverture | Durée approximative |
|------|------------|---------------------|
| **Validate Required Tests** | Politiques 200.x obligatoires | 5–15 min |
| **Validate Recommended Tests** | + recommandations (warnings) | 15–30 min |
| **All Tests** | Required + Recommended + LISA | 30–60 min |

**Pour soumission Partner Center** : sélectionner **All Tests**.

### 4.6 Lancer la suite et exporter le rapport

1. Cliquer **Run Tests**.
2. À la fin, cliquer **Export Report** → générer un fichier `.json` + `.html`.
3. Sauvegarder sous : `docs/Certification/<plan-id>-<version>/ctt-report.{html,json}`.

---

## 5. Critères de réussite

| Critère | Seuil | Action si non respecté |
|---------|-------|------------------------|
| **Required tests** | 100 % PASS | 🔴 Bloquant — corriger l'image et rebuild Packer |
| **Recommended tests** | ≥ 95 % PASS, warnings documentés | 🟡 Documenter dans Partner Center "Notes for certification" |
| **LISA tests** | 100 % PASS | 🔴 Bloquant |

### Échecs typiques observés sur images SMW

| Test CTT | Cause potentielle | Mitigation |
|----------|-------------------|------------|
| `Linux-Provisioning-Agent-Verify` | waagent absent/inactif | T2 (déjà couvert — commit `eb64439`) |
| `Hyper-V-Storage-Network-Drivers` | `hv_netvsc` / `hv_storvsc` absents | T6 (déjà couvert — commit `0e80d6f`) |
| `Swap-On-OS-Disk-Forbidden` | swap actif sur `/dev/sda` | T3 (déjà couvert — commit `48d6cc2`) |
| `Default-Credentials-Removed` | `~/.ssh/authorized_keys` du builder présent | T4 (déjà couvert — commit `76edadc`) |
| `Latest-Security-Patches` | USN récents manquants | T5 (déjà couvert — commit `f61db01`) |
| `Cleartext-Credentials-In-Logs` | `password=...` dans `/var/log/syslog` | T7 (déjà couvert — commit `3f9c597`) |

---

## 6. Soumission du rapport à Partner Center

1. Naviguer vers **Partner Center → Offer → Plan overview → VM image versions**.
2. Pour la version cible (ex. `6.0.20260608`), cliquer **Upload** dans la zone
   **Certification test results** (Notes for certification).
3. Uploader le `ctt-report.html` + `ctt-report.json`.
4. Compléter le champ **Notes for certification** avec :

```text
Linux VM image — Ubuntu 22.04 LTS Gen2 — kernel 6.8.0-1052-azure
- Stack : MediaWiki 1.43.0, Semantic MediaWiki 6.0.1, PHP 8.2-FPM, MySQL 8.x
- CTT report joint : ctt-report.html
- 100 % Required tests PASS, 0 LISA failures
- Default user : azureuser (SSH key only, password login disabled)
- HTTPS auto-provisioned via self-signed cert at first boot
- See: https://github.com/Cotechnoe/smw6-azure-marketplace-docs
```

---

## 7. Archivage

Sauvegarder les artefacts dans le repo (sans secrets) :

```bash
mkdir -p docs/Certification/standard-6.0.20260608/
cp /mnt/c/Users/<vous>/Downloads/ctt-report.html docs/Certification/standard-6.0.20260608/
cp /mnt/c/Users/<vous>/Downloads/ctt-report.json docs/Certification/standard-6.0.20260608/
git add docs/Certification/standard-6.0.20260608/
git commit -m "docs(cert): rapport CTT v6.0.20260608 — 100% Required PASS"
```

> ⚠️ **Ne pas committer** les clés privées, les logs SSH `auth.log`, ou
> tout fichier contenant l'IP publique de la VM dev (risque d'exposition
> historique).

---

## 8. Cleanup post-CTT

```bash
# Détruire la VM dev après archivage du rapport
make vm-dev-delete

# Sur Windows : désinstaller le CTT (optionnel)
# Settings → Apps → Azure Certification Test Tool → Uninstall
```

---

## Références

- [Azure Certification Test Tool](https://aka.ms/azurecertificationtesttool) — page officielle
- [Test your VM image](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-image#test-your-vm-image)
- [ADR-804](../adr/804-BIZ-politiques-certification-microsoft-marketplace.md) — Politiques de certification
- [ADR-701](../adr/701-TEST-protocole-qualification-post-image-vm.md) — Protocole de qualification
- Notre proxy : `packer/scripts/marketplace-ctt.sh` + `packer/scripts/integration-test.sh`
