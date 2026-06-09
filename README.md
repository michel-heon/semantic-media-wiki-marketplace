# Semantic MediaWiki — Azure Marketplace VM Offer

Industrialisation et publication sur **Microsoft Azure Marketplace** d'une offre de type **Virtual Machine** intégrant [Semantic MediaWiki](https://www.semantic-mediawiki.org/) (SMW), destinée aux organisations souhaitant déployer une base de connaissances structurée et interrogeable dans leur propre abonnement Azure.

---

## Qu'est-ce que Semantic MediaWiki ?

[Semantic MediaWiki](https://www.semantic-mediawiki.org/wiki/Semantic_MediaWiki) est une extension libre et open-source de **MediaWiki** (le moteur de Wikipédia) qui transforme un wiki classique en système de **gestion de connaissances structuré** :

- Annotation sémantique des pages via des **propriétés typées** (dates, nombres, textes, relations entre entités)
- **Requêtes inline** sur les données avec le langage `#ask` / `#show`
- Export vers le **Semantic Web** (RDF, OWL, SPARQL endpoint)
- Écosystème riche d'extensions : Page Forms, Maps, Semantic Result Formats, Cargo, etc.

SMW est adopté par des institutions académiques, des entreprises de knowledge management, des organismes publics et des projets open data dans le monde entier.

---

## Objectif du Projet

**Problème** : Déployer Semantic MediaWiki sur Azure requiert expertise Linux, PHP, MariaDB, Apache/Nginx, configuration TLS et tuning SMW — ce qui freine l'adoption en entreprise.

**Solution** : Une image VM **préconfigurée, sécurisée et certifiée** publiée sur Azure Marketplace. Le client déploie SMW en quelques clics directement dans son abonnement Azure, sans dépendance à un SaaS tiers, en conservant la **souveraineté totale de ses données**.

### Ce que l'offre inclut

| Composant | Détail |
|-----------|--------|
| **OS** | Ubuntu 22.04 LTS (image Azure endorsée) |
| **Web server** | Apache 2.4 |
| **PHP** | 8.1 – 8.4 (conforme matrice de compatibilité SMW 6.x) |
| **Base de données** | MySQL 5.7.0+ / MariaDB compatible |
| **Wiki** | MediaWiki 1.43.x – 1.44.x (versions compatibles avec SMW 6.0.1) |
| **Extension** | Semantic MediaWiki **6.0.1** (version stable, publiée le 26 août 2025) |
| **TLS** | Certificat auto-signé préconfiguré (remplaçable par Let's Encrypt) |
| **Sécurité** | Hardening OS conforme aux exigences Azure Marketplace Certification Policies |
| **Premier démarrage** | Script `firstboot` via cloud-init — configuration initiale automatisée |

---

## Architecture

```
Azure Subscription (client)
└── Resource Group
    ├── Virtual Machine (Ubuntu 22.04 LTS)
    │   ├── Apache + PHP 8.x
    │   ├── MediaWiki + SMW extension
    │   └── cloud-init firstboot
    ├── Data Disk (persistance)
    │   └── MariaDB data directory
    └── Network Security Group
        ├── HTTPS (443) — public
        ├── HTTP (80)  — redirect vers HTTPS
        └── SSH (22)   — restreint à l'admin
```

L'image est construite avec **HashiCorp Packer**, versionnée dans **Azure Compute Gallery**, et publiée via **Microsoft Partner Center**.

---

## Modèle de Licence

Offre de type **BYOL (Bring Your Own License)** — SMW et MediaWiki sont open-source (GPL). Le client paie uniquement les ressources Azure consommées. Aucun frais de licence éditeur.

---

## Structure du Dépôt

```
.
├── README.md                        # Ce fichier
├── Makefile                         # Orchestrateur principal (make help)
├── .gitignore
├── env/
│   ├── .env.dev                     # Variables publiques (versionnées)
│   ├── .env.dev.user.example        # Gabarit secrets (versionné)
│   ├── .env.dev.user                # Secrets réels (NON versionné — .gitignore)
│   └── generated/                   # Fichiers auto-générés (NON versionnés)
│       └── config.make
├── packer/
│   ├── smw-vm.pkr.hcl               # Template Packer principal
│   ├── variables.pkr.hcl            # Déclarations de variables Packer
│   ├── generated.pkrvars.hcl        # Variables runtime (NON versionné — .gitignore)
│   ├── provisioners/                # Scripts de provisionnement shell (01–08)
│   │   ├── 01-install-base.sh
│   │   ├── 02-install-php.sh
│   │   ├── 03-install-apache.sh
│   │   ├── 04-install-mysql.sh
│   │   ├── 05-install-mediawiki.sh
│   │   ├── 06-install-smw.sh
│   │   ├── 07-security-harden.sh
│   │   └── 08-cleanup-generalize.sh
│   └── scripts/
│       └── storage-provision.sh     # Gestion du cache Blob Storage
└── docs/
    ├── adr/                         # Architecture Decision Records
    └── scrum/                       # Epics, User Stories, Sprint plan
```

---

## Démarrage Rapide (Contributeurs)

### Prérequis

- [HashiCorp Packer](https://developer.hashicorp.com/packer/install) ≥ 1.11
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) ≥ 2.x
- `make`, `wget`

### Configuration initiale

```bash
# 1. Copier et remplir les secrets
cp env/.env.dev.user.example env/.env.dev.user
# Éditer env/.env.dev.user avec les valeurs du Service Principal Azure

# 2. Générer la configuration (env/generated/config.make + packer/generated.pkrvars.hcl)
make config

# 3. Vérifier les variables d'environnement
make check-env
```

### Build de l'image VM

```bash
# Initialiser les plugins Packer (une seule fois)
make packer-init

# Valider le template sans construire
make vm-validate

# Construire l'image VM dans Azure Compute Gallery
make vm-build
```

### Gestion du cache Blob Storage

```bash
# Créer le compte de stockage et le conteneur
make storage-create

# Uploader les packages (MediaWiki, SMW, Composer)
make storage-upload

# Vérifier la présence de tous les packages
make storage-verify

# Lister les blobs présents
make storage-list

# Afficher les URLs des packages
make storage-urls
```

### Aide

```bash
make help
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/architecture/smw-azure-marketplace-architecture.md](./docs/architecture/smw-azure-marketplace-architecture.md) | Architecture cible SMW sur Azure Marketplace — VM, Packer, firstboot, certification, GTM |
| [docs/adr/](./docs/adr/README.md) | Architecture Decision Records — toutes les décisions du projet |
| [docs/adr/200-INFRA-azure-infrastructure-vm-offer.md](./docs/adr/200-INFRA-azure-infrastructure-vm-offer.md) | Infrastructure Azure (Compute Gallery, NSG, ARM, Data Disk) |
| [docs/adr/300-SEC-securite-hardening-vm-certification.md](./docs/adr/300-SEC-securite-hardening-vm-certification.md) | Hardening OS et conformité certification Azure |
| [docs/adr/302-SEC-sso-microsoft-entra-id.md](./docs/adr/302-SEC-sso-microsoft-entra-id.md) | SSO via Microsoft Entra ID |
| [docs/adr/602-DEVOPS-makefile-orchestrateur.md](./docs/adr/602-DEVOPS-makefile-orchestrateur.md) | Makefile comme orchestrateur standard |
| [docs/adr/800-BIZ-publication-azure-marketplace-vm-offer.md](./docs/adr/800-BIZ-publication-azure-marketplace-vm-offer.md) | Conformité et publication Azure Marketplace |

---

## Statut du Projet

> **Phase actuelle : Initialisation — cadrage architectural**

- [x] Définition du projet et choix technologiques
- [ ] Architecture Decision Records (ADRs) — adaptation au projet SMW (importés de DSpace, en cours de révision)
- [ ] Provisioners Packer (scripts d'installation SMW)
- [ ] ARM template client
- [ ] Pipeline CI/CD (build + test + release)
- [ ] Certification Azure Marketplace
- [ ] Publication Partner Center

---

## Liens Utiles

- [Semantic MediaWiki — site officiel](https://www.semantic-mediawiki.org/)
- [MediaWiki — site officiel](https://www.mediawiki.org/)
- [Azure Marketplace — VM Offer](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/marketplace-virtual-machines)
- [Azure Marketplace Certification Policies](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies)
- [HashiCorp Packer — documentation](https://developer.hashicorp.com/packer/docs)
