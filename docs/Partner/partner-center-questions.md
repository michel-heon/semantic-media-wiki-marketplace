# Partner Center — Réponses aux questions de création d'offre

## Contexte

Document de log des réponses apportées aux questions du portail Microsoft Partner Center
lors de la création et configuration de l'offre **Azure Virtual Machine** pour Semantic MediaWiki.

**Référence Microsoft** : [Create a virtual machine offer on Microsoft Marketplace](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-offer-setup)  
**ADRs associés** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md), [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md)

---

## Étape 1 : Offer setup — Offer ID & Offer alias

### Question Partner Center

> **Offer ID** : Use only lowercase, alphanumeric characters, dashes or underscores.
> ID cannot end with "-preview" and cannot be modified after selecting Create.
>
> **Offer alias** : This name won't be used in Microsoft Marketplace listing and is solely
> for reference within Partner Center.

### Contraintes Microsoft

| Champ | Contraintes |
|-------|------------|
| **Offer ID** | Lowercase, alphanumérique + tirets/underscores uniquement · Max 50 chars · Ne peut pas se terminer par `-preview` · **IMMUABLE après création** · Visible dans l'URL Marketplace et via `az` / PowerShell |
| **Offer alias** | Nom interne Partner Center · Non visible par les clients · Pas de contrainte stricte sur la casse |

### 5 Options proposées

| # | Offer ID | Offer alias | Analyse |
|---|----------|-------------|---------|
| **1** ⭐ | `smw-knowledge-base` | `SMW Knowledge Base VM` | **Recommandé** — déjà décidé dans ADR-800 (`OFFER_ID="smw-knowledge-base"`). Décrit le cas d'usage (base de connaissances sémantique). Cohérent avec le pattern Cotechnoe. |
| **2** | `semantic-mediawiki` | `Semantic MediaWiki — Azure VM` | Nom produit complet, visibilité SEO maximale. Trop générique — ne différencie pas la valeur ajoutée. |
| **3** | `smw-semantic-wiki` | `SMW Semantic Wiki Platform` | Compromis acronyme + description. Légèrement redondant (semantic + wiki). |
| **4** | `smw-research-platform` | `SMW Research & Knowledge Platform` | Cible explicitement le segment universités/recherche (personas ADR-801). Plus segmenté mais moins universel. |
| **5** | `mediawiki-smw` | `MediaWiki + Semantic MediaWiki VM` | Met en avant MediaWiki (plus connu du grand public) avec SMW en complément. Suit le pattern `apache-jena-fuseki`. |

### Décision retenue

| Champ | Valeur |
|-------|--------|
| **Offer ID** | `smw-knowledge-base` |
| **Offer alias** | `Semantic MediaWiki — Azure VM` |

**Justification** :
- **Offer ID** : déjà validé dans ADR-800 (`OFFER_ID="smw-knowledge-base"`). Immuable après création. Orienté usage client — visible dans l'URL Marketplace publique et via `az` / PowerShell. Cohérent avec le pattern Cotechnoe (`dspace-9-ir`, `vivo-research-profiles`, `apache-jena-fuseki`).
- **Offer alias** : nom produit complet retenu plutôt que l'acronyme `SMW`. Purement interne au Partner Center (jamais visible par les clients), sans contrainte de format — le nom complet est plus immédiatement reconnaissable dans le dashboard pour l'équipe (P2 Nadia, P5 Jérôme).

---

## Étape 2 : Properties — Categories & Legal

### Question Partner Center

> **Categories** : Define the categories used to group your offer on the marketplace.
> Select at least 1 primary category (max 2 categories, max 2 subcategories each).
>
> **Legal** : Use the Standard Contract for Microsoft's commercial marketplace, or provide
> your own Terms and conditions.

### Contraintes Microsoft

| Champ | Contraintes |
|-------|------------|
| **Categories** | Au moins 1 catégorie primaire obligatoire · Max 2 catégories (primaire + secondaire) · Max 2 sous-catégories par catégorie |
| **Legal** | Option 1 : Standard Contract Microsoft (case à cocher) · Option 2 : lien T&C · Option 3 : texte T&C · Amendements universels et/ou custom possibles en complément du Standard Contract |

### Décision retenue

#### Categories

| Niveau | Catégorie | Sous-catégorie |
|--------|-----------|----------------|
| **Primaire** | Web | Blogs & CMS |
| **Secondaire** | IT & Management Tools | Business Applications |

#### Legal

| Champ | Valeur |
|-------|--------|
| **Standard Contract** | ✅ Coché — Use the Standard Contract for Microsoft's commercial marketplace |
| **Universal amendment** | *(vide — aucun amendement)* |
| **Custom amendments** | *(aucun)* |

**Justification** :
- **Web → Blogs & CMS** : MediaWiki est fondamentalement une plateforme wiki/CMS — catégorie la plus littéralement exacte et visible par les buyers cherchant un CMS déployable sur Azure.
- **IT & Management Tools → Business Applications** : positionne SMW comme outil enterprise de gestion de connaissances, cohérent avec les personas B2B (Thomas, Nadia, Jérôme).
- **Standard Contract** : recommandé par Microsoft pour les ISVs ; simplifie le processus d'achat enterprise ; évite de rédiger des T&C from scratch. Les licences open-source (GPL MediaWiki, MIT SMW) seront couvertes dans la section de l'Offer listing (tiers composants), pas dans ce champ.

---

---

## Q3 — Offer listing

| Champ | Valeur |
|-------|--------|
| **Name** | `Semantic MediaWiki — Azure VM` *(repris de Q1)* |
| **Search results summary** | `Semantic MediaWiki on Azure: turn your wiki into a queryable knowledge graph. Pre-configured, hardened, and deployable in minutes.` |
| **Privacy policy URL** | `https://github.com/Cotechnoe/server-azure-marketplace-docs/blob/main/PRIVACY.md` |

### Short description (≤ 256 chars → ~1 858 utilisés ici — vérifier limite exacte Partner Center)

```
Semantic MediaWiki transforms your Azure VM into a self-hosted knowledge graph platform — structured, queryable, and fully under your control. Based on MediaWiki (the software powering Wikipedia), it adds typed property annotations directly to wiki pages, turning free-form content into machine-readable, queryable data.

This Marketplace image delivers the complete stack pre-configured and hardened: MediaWiki 1.43, Semantic MediaWiki 6.0, SemanticResultFormats, Maps, PHP 8.2 FPM, MySQL 8.0, and Apache 2.4 on Ubuntu 22.04 LTS. Deploy in minutes using the Azure portal first-boot wizard — no SSH session, no manual installation, no configuration scripting required.

Authors annotate wiki pages using a simple inline syntax. Semantic MediaWiki automatically builds a knowledge graph from those annotations. Any team member can then embed live #ask queries on any page — tables filtered by status, maps of geographic entities, charts of project timelines — without SQL, scripting, or a data engineer.

Built for organizations that need a governed, auditable knowledge base: universities documenting research projects and publications; enterprises maintaining internal standards, policies, and asset inventories; compliance teams tracking regulatory obligations; and IT departments preserving institutional memory across team transitions.

Your data never leaves your Azure subscription. No SaaS dependency, no vendor lock-in, no telemetry sent to Cotechnoe. Choose the Azure region that meets your data residency requirements. GDPR-ready by design: the VM hosts your data exclusively within your own tenant.

Hardened for production: SSH key-only authentication, UFW firewall (ports 22, 80, 443 only), MySQL bound to localhost, PHP-FPM under a non-root user, and automatic HTTPS redirect. Supported VM sizes: Standard_B2ms and Standard_B4ms for evaluation; Standard_D2s_v3 (recommended), Standard_D4s_v3, and Standard_D8s_v3 for production.
```

### Description (≤ 5 000 chars HTML)

```html
<p>Semantic MediaWiki is an open-source extension to MediaWiki — the software that powers Wikipedia — that transforms a standard wiki into a structured-data platform. Authors annotate wiki pages with typed properties using a simple inline syntax. SMW automatically builds a queryable knowledge graph that any team member can search and query without SQL, scripting, or a dedicated data engineer.</p>

<p>This Azure Marketplace image delivers a fully pre-configured, hardened VM ready to use. Deploy from the Azure portal, complete the first-boot wizard, and your knowledge base is live — in minutes, not days. All data stays within your Azure subscription.</p>

<h2>Who benefits</h2>
<ul>
  <li><strong>Universities and research institutions</strong> — document research projects, publications, authors, and datasets with structured annotations; query across the entire corpus directly from a wiki page</li>
  <li><strong>Enterprise knowledge teams</strong> — centralize internal standards, policies, and glossaries in a living document system where every concept is typed, linked, and queryable</li>
  <li><strong>Compliance and quality teams</strong> — track IT assets, software licenses, or regulatory requirements as structured wiki pages; generate live compliance dashboards without exporting to a spreadsheet</li>
  <li><strong>IT and documentation teams</strong> — document systems, runbooks, and architecture decisions with semantic links that surface related content automatically across the entire wiki</li>
</ul>

<h2>Key capabilities</h2>
<ul>
  <li>Annotate any wiki page with typed, machine-readable properties — no separate database schema or ETL pipeline required</li>
  <li>Embed live <strong>#ask queries</strong> on any page: tables, maps, charts, and calendars that update automatically as underlying data changes</li>
  <li>Export your knowledge graph as RDF/OWL or query it via a SPARQL endpoint — ready for integration with external reporting and BI tools</li>
  <li><strong>SemanticResultFormats</strong> — render query results as bar charts, pie charts, timelines, or geographic maps out of the box</li>
  <li>Full MediaWiki feature set: revision history, granular access control, file uploads, discussion pages, and a rich extension ecosystem</li>
</ul>

<h2>What is included</h2>
<ul>
  <li><strong>MediaWiki 1.43</strong> — the open-source wiki platform powering Wikipedia and thousands of organizations worldwide</li>
  <li><strong>Semantic MediaWiki 6.0</strong> — structured data, semantic queries, and knowledge-graph capabilities on top of MediaWiki</li>
  <li><strong>SemanticResultFormats</strong> — additional output formats: charts, tables, calendars, and timelines for #ask queries</li>
  <li><strong>Maps</strong> — geographic data visualization directly on wiki pages using Leaflet</li>
  <li><strong>PHP 8.2 FPM</strong>, <strong>MySQL 8.0</strong>, and <strong>Apache 2.4</strong> with automatic HTTP to HTTPS redirect</li>
  <li><strong>Ubuntu 22.04 LTS</strong> — long-term supported base OS, supported until April 2027 (standard) and 2032 (ESM)</li>
  <li>Self-signed HTTPS certificate auto-provisioned at first boot — replace with a Let's Encrypt or CA-signed certificate at any time</li>
</ul>

<h2>Security posture</h2>
<ul>
  <li>SSH key authentication enforced — password login is disabled at the OS level</li>
  <li>UFW firewall: only ports 22 (SSH), 80 (HTTP redirect), and 443 (HTTPS) open by default</li>
  <li>MySQL bound to localhost — the database port is never exposed externally</li>
  <li>PHP-FPM running under a dedicated, non-root system user with minimal privileges</li>
  <li>Automatic HTTP to HTTPS redirect; HSTS header configurable in Apache</li>
  <li>Built and tested against Azure Marketplace certification and CIS benchmark recommendations</li>
</ul>

<h2>Data sovereignty and compliance</h2>
<p>All data — wiki pages, user accounts, semantic annotations, and uploaded files — resides exclusively within your Azure subscription and the Azure region you select. Cotechnoe has no access to your data. Choose the Azure region that meets your data residency and sovereignty requirements. Fully compatible with GDPR obligations for EU-based deployments. No telemetry or data is sent to Cotechnoe.</p>

<h2>Get started in minutes</h2>
<p>Select a VM size — Standard_B2ms or Standard_B4ms for evaluation and small teams, Standard_D2s_v3 (recommended default) or larger for production workloads — deploy from Azure Marketplace, and complete the first-boot wizard to set your domain and administrator credentials. No prior MediaWiki experience is required. Full documentation, a step-by-step getting-started guide, and architecture notes are available at the support link below.</p>
```

**Sources validées** :
- Tailles VM : `arm/mainTemplate.json` (lignes 34-42) + `arm/createUIDefinition.json` (lignes 170-184) — valeurs exactes, aucune hallucination
- Stack : `packer/provisioners/` — versions confirmées dans les scripts
- Privacy policy : `docs/smw6-azure-marketplace-docs/PRIVACY.md` — créé le 2026-05-18, à pousser sur `Cotechnoe/server-azure-marketplace-docs`

### Product information links (≤ 25)

> ⚠️ **Alerte URL** : La privacy policy dans Partner Center pointe vers
> `https://github.com/Cotechnoe/server-azure-marketplace-docs/…` mais le vrai repo git est
> `Cotechnoe/smw6-azure-marketplace-docs`. À corriger avant soumission.

| # | Name (affiché dans Partner Center) | Link | Vérifié |
|---|-------------------------------------|------|---------|
| 1 | `Documentation` | `https://cotechnoe.github.io/smw6-azure-marketplace-docs/` | ✅ |
| 2 | `Getting Started Guide` | `https://github.com/Cotechnoe/smw6-azure-marketplace-docs/blob/main/docs/Deploying-from-Marketplace.md` | ✅ |
| 3 | `Post-Deployment Verification` | `https://github.com/Cotechnoe/smw6-azure-marketplace-docs/blob/main/docs/Post-Deployment-Verification.md` | ✅ |
| 4 | `Semantic MediaWiki Basics` | `https://github.com/Cotechnoe/smw6-azure-marketplace-docs/blob/main/docs/Semantic-MediaWiki-Basics.md` | ✅ |
| 5 | `Administration Guide` | `https://github.com/Cotechnoe/smw6-azure-marketplace-docs/blob/main/docs/Administering-the-Wiki.md` | ✅ |
| 6 | `HTTPS & TLS Certificate Setup` | `https://github.com/Cotechnoe/smw6-azure-marketplace-docs/blob/main/docs/HTTPS-TLS-Certificate.md` | ✅ |
| 7 | `Troubleshooting` | `https://github.com/Cotechnoe/smw6-azure-marketplace-docs/blob/main/docs/Troubleshooting.md` | ✅ |
| 8 | `Semantic MediaWiki Official Docs` | `https://www.semantic-mediawiki.org/wiki/Help:Contents` | ✅ |
| 9 | `MediaWiki Official Documentation` | `https://www.mediawiki.org/wiki/MediaWiki` | ✅ |
| 10 | `Report an Issue` | `https://github.com/Cotechnoe/smw6-azure-marketplace-docs/issues` | ✅ |

**Décision** : 10 liens vérifiés — accueil GitHub Pages (lien #1), docs individuelles en GitHub blob (liens #2–7, les URLs `github.io/docs/*.md` retournent 404 faute de Jekyll config), documentation officielle SMW + MediaWiki, support GitHub Issues.

---

## Étape 4 — Plan overview : Plan ID & Plan name

### Question Partner Center

> **Plan ID** : Use only lowercase, alphanumeric characters, dashes or underscores.
> Cannot end in "-preview". **Cannot be modified after selecting Create.**
>
> **Plan name** : The plan name as displayed to customers in Microsoft Marketplace.

### Contraintes Microsoft

| Champ | Contraintes |
|-------|------------|
| **Plan ID** | Lowercase, alphanumérique + tirets/underscores · **IMMUABLE après création** · Apparaît dans l'URN de l'image : `cotechnoe:smw-knowledge-base:<plan-id>:<version>` |
| **Plan name** | Nom affiché aux clients dans le Marketplace · Max 50 chars |

### Décision retenue

| Champ | Valeur |
|-------|--------|
| **Plan ID** | `standard` |
| **Plan name** | `Semantic MediaWiki Standard` |

> ⚠️ **Plan ID immuable** — ne peut plus être modifié.
> Note : Le Plan name diverge légèrement de l'ADR-800 Décision 6 (`SMW Knowledge Base — Standard` → `Semantic MediaWiki Standard`). ADR-800 mis à jour en conséquence.

**Sources validées** :
- Plan ID `standard` : `docs/adr/800-BIZ-publication-azure-marketplace-vm-offer.md` (Décision 6, ligne 548 `PLAN_ID="standard"`)
- URN pattern : convention Azure Marketplace VM Offer

---

## Étape 4b — Plan setup : Azure regions

### Question Partner Center

> Configure the Azure regions in which your plan should be available.
> Each plan must be made available in at least one region.

### Options disponibles

| Région | Sélection |
|--------|-----------|
| **Azure Global** | ✅ Coché |
| **Azure Government** | ☐ Non coché |

### Décision retenue

**Azure Global uniquement** — couvre tous les marchés commerciaux mondiaux (Canada Central prioritaire per ADR-800 Décision 6).
Azure Government non sélectionné : exige des certifications FedRAMP/DoD non applicables à cette offre.

**Sources validées** :
- ADR-800 Décision 6 : « Regions: Tous marchés (Canada Central prioritaire) »

---

## Q5 — Plan listing

**Page Partner Center** : Plans > Semantic MediaWiki Standard > Plan listing

---

### Plan name (pré-rempli automatiquement)

```
Semantic MediaWiki Standard
```

---

### Plan summary (88 / 100 chars max)

```
Full-stack Semantic MediaWiki 6.0 on Ubuntu 22.04 LTS. Usage-based per vCPU — no commitment.
```

---

### Plan description (≤ 3 000 chars, texte brut)

```
This plan deploys a complete, pre-configured Semantic MediaWiki stack on an Azure VM. All software is installed, integrated, and hardened at image build time. No post-deployment configuration scripts, no SSH session, no manual package installation required. Deploy from the Azure portal and complete the first-boot wizard to set your domain, admin credentials, and HTTPS certificate.

Included software stack:
• MediaWiki 1.43 — the open-source wiki platform powering Wikipedia and thousands of organizations worldwide
• Semantic MediaWiki 6.0 — typed property annotations and queryable knowledge-graph capabilities on top of MediaWiki
• SemanticResultFormats — query results rendered as bar charts, pie charts, tables, timelines, and calendars
• Maps — geographic data visualization directly on wiki pages using Leaflet
• PHP 8.2 FPM — FastCGI process manager running under a dedicated non-root system user
• MySQL 8.0 — bound to localhost only; the database port is never exposed externally
• Apache 2.4 — with automatic HTTP-to-HTTPS redirect and HSTS header support
• Ubuntu 22.04 LTS — standard support until April 2027; Extended Security Maintenance available until 2032

Supported VM sizes:
• Standard_B2ms (2 vCPU, 8 GB RAM) — evaluation, proof-of-concept, and demo environments
• Standard_B4ms (4 vCPU, 16 GB RAM) — small teams and pilot deployments
• Standard_D2s_v3 (2 vCPU, 8 GB RAM) — recommended default for production wikis up to ~50 concurrent users
• Standard_D4s_v3 (4 vCPU, 16 GB RAM) — medium-sized wikis and active editorial teams
• Standard_D8s_v3 (8 vCPU, 32 GB RAM) — large wikis and high-traffic production deployments

Storage configuration:
• OS disk: 50 GB Premium SSD (Ubuntu 22.04 LTS system, application binaries, and configuration)
• Data disk: 128 GB Premium SSD (MySQL databases, wiki file uploads, and application logs)

Security posture:
• SSH key authentication enforced — password login disabled at the OS level
• UFW firewall: only ports 22, 80, and 443 open by default
• MySQL bound to 127.0.0.1 — no external database exposure
• PHP-FPM running under a dedicated non-root system user
• Automatic HTTP-to-HTTPS redirect; self-signed certificate provisioned at first boot

Pricing model:
Usage-based billing per vCPU per hour. No upfront cost, no minimum term, no reservation required. You pay only for compute hours consumed. Stop the VM to stop billing. Resize the VM at any time by stopping and restarting — the data disk is preserved.

Availability:
Azure Global — available in all commercial Azure regions worldwide. Select the region that best meets your data residency, latency, and compliance requirements.
```

### Décision retenue

Champs remplis selon les contraintes MS (summary ≤ 100 chars, description ≤ 3 000 chars, texte brut).
Description orientée plan uniquement (pas l'offre) — conforme à la directive Microsoft « Describe the plan only, not the offer. »

**Sources validées** :
- VM sizes : `arm/mainTemplate.json` lignes 34–42
- Stack versions : `packer/provisioners/` (01 à 08)
- Contraintes de champs : https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-plan-listing

---

## Étape 6 : Pricing and availability

### Question Partner Center

> **License model** : Select the license model for this plan.
> **Pricing** : Enter the price per vCPU per hour.
> **Free trial** : Offer a free trial period.
> **Markets** : Select markets where this plan is available.

### Contraintes Microsoft

| Champ | Contraintes |
|-------|------------|
| **License model** | `Usage-based monthly billed plan` — **IMMUABLE par marché après publication** |
| **Pricing option** | Per vCPU — prix fourni pour 1 vCPU, Azure multiplie par le nombre de vCPUs de la VM choisie |
| **Free trial** | 1, 3 ou 6 mois — **ne peut pas être désactivé après publication** |
| **VM software reservation** | Optionnel — non retenu (sélection `No`) |

### Analyse tarifaire

| Scénario | Prix/vCPU/h | Total logiciel D2s_v3 (2 vCPU) | Total client/mois (CAD) |
|----------|-------------|-------------------------------|------------------------|
| Bitnami MediaWiki | Free | $0.00 | ~$97 (compute seul) |
| Cognosys stacks open-source | ~$0.01–$0.03 | $0.02–$0.06/h | ~$112–$138 |
| **Retenu — SMW stack** | **$0.07** | **$0.14/h** | **~$238** |
| Tarif mid-tier | $0.10–$0.15 | $0.20–$0.30/h | ~$259–$311 |

**Justification du $0.07/vCPU/heure** :
- SMW est open-source mais la valeur facturée = stack entier pré-configuré (MediaWiki 1.43 + SMW 6.0.1 + SemanticResultFormats + Apache + MySQL 8.0 + PHP 8.2 FPM) + hardening sécurité (UFW, SSH-key-only, MySQL localhost) + first-boot wizard automatisé
- Positionné au-dessus des stacks CMS génériques (Cognosys ~$0.01–$0.03) — valeur ajoutée réelle en configuration et sécurité
- En-dessous des offres mid-tier et logiciels propriétaires ($0.10+) — reste accessible aux équipes techniques et PME
- Total ~$238 CAD/mois sur D2s_v3 (2 vCPU / 8 GB) = VM recommandée par défaut, compétitif pour un wiki d'entreprise géré

**Décision ADR-800** : confirmée — Décision 6, lignes 427–446.

### Décision retenue

| Champ | Valeur |
|-------|--------|
| **License model** | `Usage-based monthly billed plan` |
| **Pricing option** | Per vCPU |
| **Price per vCPU** | `0.07` USD/heure |
| **Free trial** | One Month |
| **VM software reservation** | Yes — 1-year savings: 5% |
| **2-year savings** | Non activé |
| **5-year savings** | Non activé |
| **Effective dates** | Aucune (défaut) |
| **Plan visibility** | Public |
| **Hide plan** | Non coché |
| **Markets** | Tous les marchés disponibles (sélection par défaut) |

**Sources validées** :
- ADR-800 Décision 6 : `docs/adr/800-BIZ-publication-azure-marketplace-vm-offer.md` lignes 427–446
- Contraintes de champs : https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-plan-pricing-and-availability

---

---

## Étape 7 : Technical configuration

### Question Partner Center

> **Source image** : Select the source image type.
> **Gallery image** : Select the Azure Compute Gallery and image definition.
> **Image version** : Select the image version to use.

### Contraintes Microsoft

| Champ | Contraintes |
|-------|------------|
| **Source image type** | `Azure Compute Gallery` — requis pour les offres VM publiées via gallery |
| **Gallery image definition** | Doit avoir `SecurityType = TrustedLaunch` — les definitions avec `TrustedLaunchSupported` n'apparaissent **pas** dans le dropdown |
| **Image version** | Version Packer publiée, au format `major.minor.YYYYMMDD` (`provisioningState = Succeeded` requis) |

### Problème rencontré : image definition absente du dropdown

> **Symptôme** : `galSMWMarketplace / smw-knowledge-base` n'apparaissait pas dans le
> dropdown "Gallery image" du Partner Center Technical Configuration.
>
> **Cause** : l'image definition avait été créée avec `SecurityType = TrustedLaunchSupported`
> au lieu de `SecurityType = TrustedLaunch`. Partner Center filtre strictement —
> seules les definitions avec `TrustedLaunch` sont visibles.

**Comparaison DSpace vs SMW (avant fix) :**

| Gallery | SecurityType | Visible dropdown |
|---------|-------------|-----------------|
| `galDSpaceMarketplace` | `TrustedLaunch` | ✅ OUI |
| `galSMWMarketplace` (avant fix) | `TrustedLaunchSupported` | ❌ NON |
| `galSMWMarketplace` (après fix) | `TrustedLaunch` | ✅ OUI |

**Correction exécutée (2026-05-17) :**

```bash
# 1. Supprimer toutes les versions existantes
az sig image-version delete --resource-group rg-smw-marketplace \
  --gallery-name galSMWMarketplace --gallery-image-definition smw-knowledge-base \
  --gallery-image-version <version>  # répété pour chaque version

# 2. Supprimer l'image definition (TrustedLaunchSupported)
az sig image-definition delete --resource-group rg-smw-marketplace \
  --gallery-name galSMWMarketplace --gallery-image-definition smw-knowledge-base

# 3. Recréer avec SecurityType=TrustedLaunch
az sig image-definition create \
  --resource-group rg-smw-marketplace \
  --gallery-name galSMWMarketplace \
  --gallery-image-definition smw-knowledge-base \
  --publisher cotechnoe --offer smw-knowledge-base --sku standard \
  --os-type Linux --hyper-v-generation V2 \
  --features "SecurityType=TrustedLaunch"

# 4. Recréer la version depuis la managed image
az sig image-version create \
  --resource-group rg-smw-marketplace \
  --gallery-name galSMWMarketplace \
  --gallery-image-definition smw-knowledge-base \
  --gallery-image-version 6.0.20260517 \
  --managed-image "/subscriptions/ae487cf3-c3af-4376-9ce6-406790b4bece/resourceGroups/rg-smw-marketplace/providers/Microsoft.Compute/images/tmp-smw-knowledge-base-6.0.1-20260517" \
  --target-regions canadacentral
```

**Vérification finale :**

```bash
az sig image-definition list \
  --resource-group rg-smw-marketplace \
  --gallery-name galSMWMarketplace \
  --query "[].{Name:name, SecurityType:features[?name=='SecurityType'].value|[0], HyperVGen:hyperVGeneration, State:provisioningState}" \
  -o table
# Résultat : smw-knowledge-base | TrustedLaunch | V2 | Succeeded ✅
```

### Décision retenue

| Champ | Valeur |
|-------|--------|
| **Source image type** | `Azure Compute Gallery` |
| **Subscription** | `ae487cf3-c3af-4376-9ce6-406790b4bece` (cotechnoe) |
| **Gallery** | `galSMWMarketplace` (resource group : `rg-smw-marketplace`, région : `Canada Central`) |
| **Image definition** | `smw-knowledge-base` (`SecurityType = TrustedLaunch`, Gen2, Ubuntu 22.04 LTS) |
| **Image version** | `6.0.20260517` (`provisioningState = Succeeded`) |

**Sources validées** :
- Image definition : `az sig image-definition list --resource-group rg-smw-marketplace --gallery-name galSMWMarketplace` — vérifiée le 2026-05-17
- Version gallery : `az sig image-version list --resource-group rg-smw-marketplace --gallery-name galSMWMarketplace --gallery-image-definition smw-knowledge-base` — `provisioningState = Succeeded`
- Prévention régression : `packer/smw-vm.pkr.hcl` commentaire + ADR-800 Décision 2

---

## Étape 7b : Technical configuration — Properties

### Question Partner Center

> **Properties** : Select the properties this plan supports.

### Analyse case par case

| Propriété | Décision | Justification |
|-----------|----------|---------------|
| **Supports VM extensions** | ✅ Coché | Standard — permet Azure Monitor, agents backup, Defender for Cloud, etc. Aucune raison de décocher. |
| **Supports backup** | ✅ Coché | Disque de données 128 GB contient MySQL (wiki pages, annotations SMW, uploads). Les clients doivent pouvoir activer Azure Backup. Ubuntu 22.04 LTS supporte l'agent Azure Backup. |
| **Supports accelerated networking** | ✅ Coché | Ubuntu 22.04 LTS inclut les drivers Mellanox VF requis. Disponible sur les VM recommandées (Standard_D2s_v3, D4s_v3, D8s_v3). Non disponible sur Standard_B2ms/B4ms mais Azure gère silencieusement l'absence de support — aucun risque à cocher. |
| **Is a network virtual appliance** | ☐ Non coché | SMW est une application wiki/CMS, pas un équipement réseau. |
| **Supports NVMe** | ☐ Non coché | Disques Standard SSD Premium LRS suffisants. Pas de charge I/O nécessitant NVMe. |
| **Supports cloud-init configuration** | ☐ Non coché | Ubuntu 22.04 a cloud-init installé, mais l'initialisation SMW passe par `08-firstboot-setup.sh` (systemd oneshot), pas cloud-init. Cocher induirait en erreur les clients qui s'attendraient à passer des user-data cloud-init. |
| **Supports Microsoft Entra Identity authentication** | ☐ Non coché | ADR-302 documente SSO via Entra ID mais c'est une configuration post-déploiement optionnelle — non intégrée dans l'image. Ne pas cocher pour ne pas créer une fausse attente. |
| **Supports hibernation** | ☐ Non coché | Hibernation non testée, non validée pour SMW. MySQL en cours d'exécution + état wiki en mémoire — risque de corruption lors d'une hibernation non contrôlée. |
| **Supports remote desktop/SSH** | ✅ Coché | SSH key-only authentication activé dans l'image. Obligatoire pour la gestion et le support. |
| **Requires custom ARM template for deployment** | ✅ Coché | `arm/mainTemplate.json` + `arm/createUIDefinition.json` gèrent : disque de données 128 GB, NSG (ports 22/80/443), paramètres first-boot (domaine, email admin). Sans le template custom, le disque de données et la configuration réseau ne seraient pas provisionnés correctement. |

### Décision retenue (cases cochées)

| # | Propriété |
|---|-----------|
| ✅ | Supports VM extensions |
| ✅ | Supports backup |
| ✅ | Supports accelerated networking |
| ✅ | Supports remote desktop/SSH |
| ✅ | Requires custom ARM template for deployment |

**Sources validées** :
- `arm/mainTemplate.json` — disque de données, NSG, paramètres first-boot
- `arm/createUIDefinition.json` — UI de déploiement custom
- `packer/provisioners/08-firstboot-setup.sh` — init non cloud-init
- ADR-302 : SSO Entra ID optionnel, post-déploiement uniquement

---

## Étape 7c : Technical configuration — Recommended VM sizes & Open ports

### Recommended VM sizes (6 / 6 slots utilisés)

| Priorité | Taille | vCPU / RAM | Usage recommandé |
|----------|--------|-----------|-----------------|
| 1 | `Standard_B2ms` | 2 vCPU / 8 GB | Évaluation, POC, démo — coût minimal |
| 2 | `Standard_D2s_v3` | 2 vCPU / 8 GB | Production légère (≤ 50 users) — **défaut recommandé** |
| 3 | `Standard_D4s_v3` | 4 vCPU / 16 GB | Wikis moyens, équipes éditoriales actives |
| 4 | `Standard_D8s_v3` | 8 vCPU / 32 GB | Wikis larges, fort trafic |
| 5 | `Standard_B4ms` | 4 vCPU / 16 GB | Pilotes et déploiements équipe (burstable) |
| 6 | `Standard_E2s_v3` | 2 vCPU / 16 GB | Wikis sémantiques lourds — MySQL bénéficie du double de RAM pour les requêtes #ask volumineuses |

> Ordre : du moins coûteux au plus puissant, avec `Standard_E2s_v3` (memory-optimized) en dernier slot pour les cas à forte charge SMW/MySQL.
> `Standard_D2s_v3` mis en second pour orienter vers la taille de production recommandée.
> Les 5 premières tailles correspondent aux `allowedSizes` de `arm/createUIDefinition.json`.

### Open ports

Port 22 (SSH) est automatiquement ouvert par Azure pour Linux — ne pas re-déclarer ici.

| Label | Port | Protocol |
|-------|------|----------|
| HTTP  | 80   | TCP |
| HTTPS | 443  | TCP |

**Justification** : UFW dans l'image n'autorise que 22/80/443. Le port 80 redirige vers 443 (HTTPS). Déclarer uniquement les ports applicatifs web, pas SSH.

**Sources validées** :
- `packer/provisioners/07-security-harden.sh` — règles UFW (22, 80, 443)
- `arm/mainTemplate.json` — NSG rules confirment les mêmes ports

---

## Étape 7d : Technical configuration — Security type

### Question Partner Center

> **Security type** : Select the security type for your Gen 2 images.
> Options : `None` · `Trusted launch (Recommended)` · `Trusted launch and confidential`

### Décision

**✅ Sélectionner : `Trusted launch (Recommended)`**

### Justification

| Critère | Valeur |
|---------|--------|
| SecurityType gallery image definition | `TrustedLaunch` (requis — voir Étape 7) |
| Image Packer construite avec | `trusted_launch_enabled = true` (Packer `azure-arm`) |
| Cohérence Partner Center → Gallery | Doit correspondre — `Trusted launch` ↔ `TrustedLaunch` |
| Confidential VM | ❌ Non requis — pas de workloads sensibles justifiant le chiffrement mémoire CPU |
| `None` | ❌ Interdit — incompatible avec une image definition `SecurityType = TrustedLaunch` |

> **Règle** : Partner Center impose que le security type sélectionné corresponde à celui
> de l'image definition dans la gallery. Sélectionner `None` avec une image `TrustedLaunch`
> produira une erreur de validation à la soumission.

### Fonctionnalités activées par Trusted Launch

| Fonctionnalité | Rôle |
|----------------|------|
| **Secure Boot** | Empêche le chargement de bootloaders/OS non signés |
| **vTPM** | Puce TPM virtuelle — stockage sécurisé des clés de démarrage |
| **Integrity monitoring** | Attestation de démarrage, visibilité dans Azure Security Center |

> Ces fonctionnalités sont transparentes pour l'utilisateur final — aucune configuration requise post-déploiement.

<!-- Prochaine étape : Étape 8 — Preview audience -->

---

## Étape 8 : Resell through CSPs

### Question Partner Center

> **Make my usage-based monthly billed plans available for resell to \***
> - `Any partner in the CSP program`
> - `Specific partners in the CSP program I select`
> - `No partners in the CSP program`

### Décision

**✅ Sélectionner : `No partners in the CSP program`**

### Justification

| Critère | Analyse |
|---------|---------|
| **Modèle tarifaire** | BYOL / Free — aucune facturation usage-based via CSP à gérer |
| **Cible initiale** | Déploiement direct — entreprises et wikis communautaires, pas de revendeurs |
| **Complexité opérationnelle** | CSP implique des accords de revente, marges, support tier-1 par le CSP — hors scope v1 |
| **Réversibilité** | Ce paramètre peut être modifié après publication — démarrer conservateur est sans risque |
| **Open-source** | SMW est open-source ; la valeur ajoutée est l'image préconfigurée, pas un accord de licence CSP |

> **Note** : La mention *"All plans with BYOL (Bring your own license) pricing are opted in"*
> s'applique automatiquement si un plan BYOL existe — sans action requise de notre part.
> Notre plan `standard` est en facturation Azure directe (infrastructure only), donc
> uniquement le choix manuel ci-dessus s'applique.

<!-- Prochaine étape : Étape 9 — Co-sell with Microsoft -->
