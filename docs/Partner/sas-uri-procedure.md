# SAS URI — Procédure de référence (T11)

**Date** : 2026-06-08
**Issue** : [#4](https://github.com/michel-heon/semantic-media-wiki-marketplace/issues/4) — T11
**ADRs** : [ADR-800 §Décision 8](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md), [ADR-802](../adr/802-BIZ-sources-officielles-azure-marketplace.md), [ADR-804](../adr/804-BIZ-politiques-certification-microsoft-marketplace.md)

---

## 1. ⚠️ Avertissement — Méthode utilisée par cette offre

> **Notre offre utilise Azure Compute Gallery (méthode recommandée 2026), pas SAS URI.**
>
> Le SAS URI est l'**ancienne méthode** d'upload d'image VM vers Partner Center.
> Microsoft a déprécié progressivement cette méthode au profit d'**Azure Compute
> Gallery** (ACG) — référence : [ADR-802 §Glossaire](../adr/802-BIZ-sources-officielles-azure-marketplace.md).
>
> **Configuration actuelle** (env/.env.dev) :
> - `GALLERY_NAME=galSMWMarketplace`
> - `GALLERY_IMAGE_NAME=smw-knowledge-base`
> - `GALLERY_IMAGE_PUBLISHER=cotechnoe`
> - Subscription : `ae487cf3-c3af-4376-9ce6-406790b4bece`
>
> Ce document existe pour deux raisons :
> 1. **Conformité ADR-800** — la Décision 8 documente l'exigence officielle Microsoft pour SAS URI (information de référence)
> 2. **Plan B** — si Partner Center exige un fallback SAS URI (cas rare), cette procédure est prête

---

## 2. Méthode actuelle : Compute Gallery (recommandée)

### 2.1 Référence d'image dans Partner Center

Partner Center → Offer → Plan → **Technical configuration** :

| Champ | Valeur |
|-------|--------|
| **Method** | Use existing Azure compute gallery |
| **Subscription** | `ae487cf3-c3af-4376-9ce6-406790b4bece` |
| **Resource group** | `rg-smw-marketplace` |
| **Compute gallery** | `galSMWMarketplace` |
| **Image definition** | `smw-knowledge-base` |
| **Image version** | (sélectionner la dernière version certifiée, ex: `6.0.20260608`) |

### 2.2 Prérequis ACG (déjà configurés)

Permissions RBAC sur la gallery — déjà appliquées via :

```bash
make marketplace-gallery-permissions
```

Le script (`packer/scripts/marketplace-gallery-permissions.sh`) :
1. Enregistre le RP `Microsoft.PartnerCenterIngestion`
2. Crée les SPs Microsoft (`Azure Marketplace VM Image Builder` + `Azure Marketplace`)
3. Assigne le rôle **Compute Gallery Image Reader** (`cf7c76d2-d6b8-4f9d-b9cb-72ce67e2049b`) sur la gallery

### 2.3 Validation Partner Center accède bien à la gallery

```bash
# Lister les role assignments sur la gallery
az role assignment list \
    --scope "/subscriptions/ae487cf3-c3af-4376-9ce6-406790b4bece/resourceGroups/rg-smw-marketplace/providers/Microsoft.Compute/galleries/galSMWMarketplace" \
    --query "[?roleDefinitionName=='Compute Gallery Image Reader'].{principalName:principalName, principalType:principalType}" \
    -o table
```

Sortie attendue : 2 SPs Microsoft assignés.

---

## 3. Méthode legacy : SAS URI sur VHD

> ⚠️ **À n'utiliser qu'en fallback explicite demandé par Partner Center.**

### 3.1 Exigences Microsoft (ADR-800 Décision 8)

| Exigence | Valeur |
|---------|--------|
| **Durée de validité** | ≥ 3 semaines après soumission (recommandé 30 jours) |
| **Permissions** | `Read` + `List` (`sp=rl`) — **jamais** Write/Delete |
| **Resource type** | Container (`sr=c`) ou Blob (`sr=b`) selon le scope |
| **Protocole** | HTTPS uniquement (`spr=https`) |
| **Format URL** | `https://<storage>.blob.core.windows.net/<container>/<vhd>?sv=...&sig=...` |
| **Format VHD** | Fixed disk VHD (.vhd, pas .vhdx, pas .qcow2) |

### 3.2 Script de génération SAS URI

```bash
#!/usr/bin/env bash
# packer/scripts/generate-vhd-sas-uri.sh
set -euo pipefail

# Variables (à surcharger via env)
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-stsmwmarketplace}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-smw-marketplace}"
CONTAINER="${CONTAINER:-vhds}"
VHD_NAME="${VHD_NAME:-smw-vm.vhd}"
EXPIRY_DAYS="${EXPIRY_DAYS:-30}"

EXPIRY=$(date -u -d "+${EXPIRY_DAYS} days" '+%Y-%m-%dT%H:%MZ')

echo "[INFO] Génération SAS URI"
echo "  Storage  : $STORAGE_ACCOUNT"
echo "  Container: $CONTAINER"
echo "  Blob     : $VHD_NAME"
echo "  Expiry   : $EXPIRY (${EXPIRY_DAYS} jours)"

# 1. Vérifier que le VHD existe
if ! az storage blob exists \
        --account-name "$STORAGE_ACCOUNT" \
        --container-name "$CONTAINER" \
        --name "$VHD_NAME" \
        --query exists -o tsv | grep -q true; then
    echo "[ERROR] Blob introuvable : $CONTAINER/$VHD_NAME"
    exit 1
fi

# 2. Générer le SAS token (read + list, HTTPS only)
SAS_TOKEN=$(az storage blob generate-sas \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$CONTAINER" \
    --name "$VHD_NAME" \
    --permissions rl \
    --expiry "$EXPIRY" \
    --https-only \
    --full-uri \
    -o tsv)

echo
echo "[OK] SAS URI généré (valide jusqu'au $EXPIRY) :"
echo "$SAS_TOKEN"
echo
echo "[NEXT] Tester l'accès :"
echo "  curl -I '$SAS_TOKEN' | head -5"
```

### 3.3 Validation du SAS URI

```bash
# 1. Test HTTP HEAD (doit renvoyer 200 OK avec Content-Type: application/octet-stream)
curl -I "$SAS_URI" 2>&1 | head -10

# 2. Vérification des paramètres requis dans l'URL
echo "$SAS_URI" | grep -oE "sp=[a-z]+" | grep -q "rl"     # permissions read+list
echo "$SAS_URI" | grep -oE "spr=https"                    # HTTPS only
echo "$SAS_URI" | grep -oE "se=[0-9TZ:-]+"                # expiry présent
```

### 3.4 Soumission dans Partner Center

Partner Center → Offer → Plan → **Technical configuration** → **Use SAS URI** :

| Champ | Valeur |
|-------|--------|
| **Method** | Use SAS URI |
| **OS VHD link** | (coller le SAS URI complet généré ci-dessus) |
| **Data disk VHD link** (optionnel) | (idem pour data disk si applicable) |

---

## 4. Comparaison ACG vs SAS URI

| Critère | Azure Compute Gallery | SAS URI |
|---------|----------------------|---------|
| **Statut Microsoft** | ✅ Recommandé 2026+ | ⚠️ Legacy, déprécié progressivement |
| **Génération** | Automatique via Packer (`shared_image_gallery_destination`) | Manuelle, expire dans 30 jours |
| **Versioning** | Natif (`6.0.20260608`, `6.0.20260615`, etc.) | Une URL par version, à régénérer |
| **Réplication régionale** | Native (`target_regions`) | Non, un blob par région |
| **Renouvellement** | Permanent (RBAC) | À refaire avant chaque expiration |
| **Sécurité** | RBAC granulaire | URL secrète unique (perte = compromis) |
| **Maintenance** | Faible (1 commande gallery permissions) | Élevée (régénération périodique) |

**Conclusion** : tant que Partner Center ne refuse pas la méthode ACG,
**ne pas utiliser SAS URI**. Cette procédure reste documentée par
conformité ADR-800 et comme plan B.

---

## 5. Checklist pré-soumission

### Cas ACG (notre cas — par défaut)

- [x] Image gallery `galSMWMarketplace` créée
- [x] Image definition `smw-knowledge-base` créée
- [x] Image version `6.0.20260608` publiée (commit `3f9c597`)
- [x] Permissions RBAC sur la gallery (`make marketplace-gallery-permissions`)
- [ ] Selectionner la version dans Partner Center → Technical configuration
- [ ] Submit for certification

### Cas SAS URI (si fallback requis)

- [ ] Export VHD depuis la gallery image (`az image export` ou `az disk grant-access`)
- [ ] Upload VHD vers blob storage (`stsmwmarketplace`, container `vhds`)
- [ ] Générer SAS URI via le script §3.2 (expiry 30 jours minimum)
- [ ] Tester accessibilité : `curl -I "$SAS_URI"` doit renvoyer 200
- [ ] Vérifier paramètres : `sp=rl`, `spr=https`, `se=` futur
- [ ] Coller dans Partner Center → Technical configuration → OS VHD link
- [ ] Submit for certification dans les 7 jours (latence ingestion Microsoft)

---

## 6. Sécurité — Ne jamais committer un SAS URI

🚨 **Un SAS URI contient un secret cryptographique** (`sig=...`) qui donne
un accès lecture au VHD pendant 30 jours à quiconque le possède.

### Règles

- ❌ **Ne jamais** committer un SAS URI dans Git (même en historique).
- ❌ **Ne jamais** poster un SAS URI dans une Issue/PR publique ou Slack.
- ✅ Coller le SAS URI directement dans Partner Center (HTTPS, formulaire).
- ✅ Logger uniquement la **partie URL sans signature** : `https://<storage>.blob.core.windows.net/<container>/<vhd>?sv=...&se=...&sp=rl` (sans `&sig=...`).
- ✅ Sauvegarder le SAS URI uniquement dans un secret manager (Azure Key Vault, 1Password, etc.) si nécessaire.

### En cas de fuite accidentelle

```bash
# Révoquer immédiatement en regénérant la clé de stockage
az storage account keys renew \
    --account-name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --key primary
```

Tous les SAS URI signés avec l'ancienne clé deviennent invalides instantanément.

---

## Références

- [ADR-800 §Décision 8](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md) — Exigences SAS URI
- [ADR-802 §Glossaire](../adr/802-BIZ-sources-officielles-azure-marketplace.md) — SAS URI vs Compute Gallery
- [ADR-804 §Validation finale](../adr/804-BIZ-politiques-certification-microsoft-marketplace.md) — Checklist
- [Microsoft Docs — Generate a SAS for VHD](https://learn.microsoft.com/en-us/azure/marketplace/azure-vm-create-using-approved-base#share-the-vhd-with-microsoft)
- [Microsoft Docs — Use Compute Gallery for Marketplace](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-use-approved-base)
- Script ACG permissions : `packer/scripts/marketplace-gallery-permissions.sh`
- Procédure CTT : [`azure-ctt-procedure.md`](azure-ctt-procedure.md)
