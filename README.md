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
├── README.md                   # Ce fichier
├── Makefile                    # Orchestrateur principal (make help)
├── packer/                     # Définitions Packer — construction de l'image VM
│   ├── smw.pkr.hcl
│   └── provisioners/           # Scripts de provisionnement shell
├── arm/                        # ARM template déployé par le client Marketplace
├── scripts/                    # Scripts utilitaires (config, tests, release)
├── env/                        # Fichiers de configuration (générés, ne pas éditer)
└── docs/
    └── adr/                    # Architecture Decision Records
```

> Le code source (Packer, ARM, scripts) sera ajouté au fur et à mesure de l'implémentation.

---

## Démarrage Rapide (Contributeurs)

```bash
# Prérequis : Azure CLI, Packer, make

# 1. Configurer l'environnement
make config

# 2. Construire l'image VM
make build

# 3. Valider la certification (Azure Marketplace Certification Test Tool)
make test

# 4. Publier une nouvelle version
make release VERSION=1.2.0
```

---

## Documentation

| Document | Description |
|----------|-------------|
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
