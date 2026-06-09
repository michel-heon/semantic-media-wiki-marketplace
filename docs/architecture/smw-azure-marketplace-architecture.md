# Architecture SMW Azure Marketplace

## 1. Objectif

Ce document decrit l'architecture cible pour publier Semantic MediaWiki (SMW) comme offre de type Azure Virtual Machine sur Microsoft Marketplace. Il consolide les decisions existantes du depot, les bonnes pratiques Microsoft Marketplace, la documentation officielle SMW et Packer, ainsi que le retour d'experience du depot `dspace-marketplace`.

Le but n'est pas de reinventer SMW, MediaWiki ou Azure Marketplace. Le produit livre une image VM reproductible, durcie, documentee et certifiable, qui permet a un client Azure de deployer une base de connaissances semantique dans son propre abonnement.

## 2. Sources et contraintes verifiees

### Sources officielles consultees

- Semantic MediaWiki, `Help:Installation`: installation recommandee par Composer; verification de compatibilite; `composer.local.json`; `wfLoadExtension( 'SemanticMediaWiki' )`; execution de `php maintenance/update.php`; verification via `Special:Version`; tests automatises recommandes hors production.
- Semantic MediaWiki, `Help:Developer_manual`: renvoie vers les guides de developpement, l'architecture guide, les extensions, les hooks, le code documentation et le processus de release.
- Semantic MediaWiki, `Help:Architecture_guide`: SMW expose un modele de donnees autour de `DataItem`, `SemanticData` et `DataValue`; SQLStore, ElasticStore et SPARQLStore sont des moteurs de stockage/requete documentes; SMW fournit API modules et hooks.
- HashiCorp Packer: Packer construit des images machine automatisees et reproductibles a partir de templates; usage attendu ici comme pipeline de golden image.
- Microsoft Partner Center, creation d'une offre VM: compte Marketplace requis, offre Azure VM creee dans Partner Center, offer ID immutable, configuration des prospects, republish requis apres modifications.
- Microsoft GTM best practices: titre clair avec mots-cles, proposition de valeur dans les premieres phrases, ressources marketing utiles, logo PNG, captures 1280 x 720, suivi des campagnes via `ocid`/`utm_*`.

### Sources internes consultees

- [README.md](../../README.md)
- [ADR 001 - Definition et cadrage du projet](../adr/001-META-definition-projet-smw-marketplace.md)
- [ADR 200 - Infrastructure Azure VM Offer](../adr/200-INFRA-azure-infrastructure-vm-offer.md)
- [ADR 300 - Hardening VM Marketplace](../adr/300-SEC-securite-hardening-vm-certification.md)
- [ADR 603 - Git workflow et versioning](../adr/603-DEVOPS-git-workflow-et-strategie-versioning.md)
- [ADR 614 - Workflow VM rapide](../adr/614-DEVOPS-dev-vm-iteration-workflow.md)
- [ADR 617 - Packer image builder](../adr/617-DEVOPS-packer-outil-construction-images-vm.md)
- [ADR 800 - Publication Azure Marketplace](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)
- Exemple DSpace: `docs/architectures/provisioning-system-overview.md`, `packer/README.md`, `docs/mkp-offer/listing.md`, `docs/mkp-offer/plan-listing.md`.

### Limites anti-hallucination

Les versions exactes doivent rester centralisees dans les variables du projet et validees contre les matrices officielles MediaWiki/SMW avant chaque release. Ce document decrit l'architecture et les points de controle; il ne remplace pas la verification de compatibilite au moment du build.

Les composants non requis pour le MVP, notamment ElasticStore ou SPARQLStore externe, sont documentes comme evolutions possibles et non comme dependances initiales.

## 3. Positionnement produit

### Offre cible

- Type d'offre: Azure Virtual Machine.
- Modele: BYOS, deploiement dans l'abonnement Azure du client.
- Licence commerciale: image gratuite/BYOL pour les logiciels open source; le client paie les ressources Azure consommees.
- Cas d'usage: base de connaissances semantique interne, documentation structuree, projet de recherche, knowledge graph leger, portail de donnees documentees.

### Proposition de valeur

Une organisation peut deployer SMW sur Azure sans assembler manuellement Ubuntu 22.04 LTS, Apache 2.4, PHP 8.2, MySQL 8.x, MediaWiki 1.43.x, SMW 6.0.1, TLS, firstboot, sauvegarde et hardening Marketplace. La souverainete des donnees reste cote client: base SQL, fichiers uploades et journaux applicatifs resident dans la VM et ses disques geres.

## 4. Architecture logique client

```text
Client Azure subscription

Resource group
  Public IP / DNS label optional
  Network Security Group
    allow 443/tcp from Internet
    allow 80/tcp from Internet for redirect and ACME HTTP-01
    allow 22/tcp from admin source or Bastion path
    deny MySQL/PHP-FPM/public internals

  Virtual Machine Ubuntu 22.04 LTS Gen2
    Apache 2.4 TLS edge
      HTTP 80 redirect to HTTPS
      HTTPS 443 serves MediaWiki
    PHP 8.2-FPM
      listens on localhost or Unix socket
    MediaWiki 1.43.x
      installed under /opt/mediawiki
      LocalSettings generated at first boot
    Semantic MediaWiki 6.0.1
      installed with Composer in MediaWiki tree
      SQLStore as MVP storage/query engine
    MySQL 8.x
      listens on 127.0.0.1 only
      data directory on /data/mysql
    systemd services
      smw-firstboot.service
      optional smw-dns-watch.timer
      health/check scripts
    Azure Linux Agent + cloud-init

  Managed data disk
    /data/mysql
    /data/uploads
    /data/backups
    /data/logs
```

### Decisions structurantes

| Domaine | Decision MVP | Raison |
|---|---|---|
| Publication | Azure VM Offer | Modele conforme au besoin de souverainete client et aux ADR existants. |
| OS | Ubuntu 22.04 LTS Gen2, image Azure approuvee | Base stable et compatible avec les exigences Marketplace Linux. |
| Web | Apache 2.4 + PHP 8.2-FPM | Aligne avec README et ADR 001; pile connue pour MediaWiki. |
| Base | MySQL 8.x, local VM | MVP autonome, simple a deployer, sans dependance PaaS. |
| SMW Store | SQLStore | Store documente par SMW et le plus simple pour une offre VM initiale. |
| Donnees | Data disk separe monte sur `/data` | Evite de mettre les donnees client sur l'OS disk. |
| TLS | Self-signed au premier boot, remplacement par certificat client ou Let's Encrypt si DNS valide | Permet un deploiement immediat et une trajectoire propre vers certificat public. |
| Admin | Aucun credential par defaut dans l'image | Exigence Marketplace et bonne pratique securite. |
| Build | Packer `azure-arm` vers Azure Compute Gallery | Reproductibilite, versioning et integration Partner Center. |

## 5. Architecture SMW et MediaWiki

### Installation SMW

La documentation SMW recommande Composer. Le provisioner doit donc installer MediaWiki, preparer Composer, ajouter SMW dans `composer.local.json`, executer `composer update --no-dev`, activer l'extension et lancer les maintenances MediaWiki.

Sequence cible:

```text
install-mediawiki.sh
  telecharge MediaWiki version cible
  installe dans /opt/mediawiki
  prepare LocalSettings template sans secrets finaux

install-smw.sh
  cree ou met a jour composer.local.json
  require mediawiki/semantic-media-wiki "~6.0" (SMW 6.0.1)
  composer update --no-dev
  ajoute wfLoadExtension( 'SemanticMediaWiki' ) dans LocalSettings template
  ne lance pas de tests SMW sur serveur production

firstboot.sh
  injecte nom du wiki, host, email admin, secrets DB
  cree/valide la base MediaWiki
  execute php maintenance/update.php
  verifie Special:Version ou maintenance script equivalent
```

### Modele de donnees

SMW structure les donnees autour de concepts documentes par son architecture guide:

- `DataValue`: perspective utilisateur, conversion et validation des valeurs entrees ou affichees.
- `DataItem`: representation interne manipulee par le systeme.
- `SemanticData`: ensemble de faits semantiques associes a une page.

Pour l'offre initiale, ces donnees restent stockees dans le store SQL de SMW, dans la meme base que MediaWiki ou selon la configuration SMW retenue au moment de l'installation. Les evolutions ElasticStore ou SPARQLStore ne sont pas incluses dans le plan standard pour eviter d'ajouter Elasticsearch ou un triple store au MVP.

### Extensions et API

SMW expose des API modules et des hooks; l'offre Marketplace doit respecter cette architecture en evitant les modifications directes au coeur SMW. Les personnalisations produit doivent prendre la forme de configuration MediaWiki/SMW, d'extensions optionnelles documentees ou de scripts d'administration. Les developpements specifiques doivent suivre le manuel developpeur SMW et les pratiques MediaWiki.

## 6. Architecture de build Packer

### Flux image

Packer v1.11+ avec le plugin `hashicorp/azure ~> 2` (HCL2).

```text
Git repository
  packer/smw-vm.pkr.hcl
  packer/variables.pkr.hcl
  packer/provisioners/01-*.sh ... 09-*.sh
        |
        v
packer init / validate / build
        |
        v
Temporary Azure build VM
        |
        v
Provisioners shell sequenciels
        |
        v
waagent -deprovision+user + cleanup
        |
        v
Azure Compute Gallery
  galSMWMarketplace/smw-knowledge-base/{smw_version}.{yyyymmdd}
        |
        v
Partner Center technical configuration
```

### Provisioners cibles

| Ordre | Script | Responsabilite |
|---:|---|---|
| 01 | `01-install-base.sh` | Paquets systeme, mises a jour, outils, utilisateurs systeme, repertoires. |
| 02 | `02-install-php.sh` | PHP 8.2-FPM et extensions requises par MediaWiki 1.43.x / SMW 6.0.1. |
| 03 | `03-install-apache.sh` | Apache, modules TLS/proxy_fcgi/rewrite/headers, vhost template. |
| 04 | `04-install-mysql.sh` | MySQL 8.x local, bind loopback, configuration minimale securisee. |
| 05 | `05-install-mediawiki.sh` | MediaWiki 1.43.x, Composer, structure `/opt/mediawiki`, templates de configuration. |
| 06 | `06-install-smw.sh` | SMW 6.0.1 par Composer (`mediawiki/semantic-media-wiki "~6.0"`), activation extension, verification installation. |
| 07 | `07-firstboot-setup.sh` | Scripts runtime, services systemd, cloud-init handoff. |
| 08 | `08-security-harden.sh` | SSH, UFW, TLS policy, permissions, Azure Linux Agent. |
| 09 | `09-cleanup-generalize.sh` | Nettoyage logs/secrets/cles, machine-id, `waagent -deprovision+user`. |

L'ordre exact peut etre ajuste pendant l'implementation, mais la generalisation doit rester la derniere operation effective de l'image.

### Workflow rapide inspire de DSpace

Le depot DSpace montre une separation utile entre build-time et runtime:

1. Phase Packer: installation des composants immuables.
2. Phase firstboot: injection des parametres client et generation des secrets.
3. Phase watch optionnelle: reconfiguration quand un FQDN Azure ou client devient disponible.

Pour SMW, il faut reprendre ce pattern sans reprendre les composants DSpace:

- `smw-firstboot.service`: idempotent, execute une seule fois, journalise dans `/var/log/smw-firstboot.log`.
- `smw-dns-watch.timer`: optionnel, surveille l'apparition d'un FQDN pour remplacer les URLs et tenter Let's Encrypt.
- `make vm-dev-create` / `make provision-push`: workflow d'iteration rapide de l'ADR 614 avant un build Packer complet.

## 7. First boot et parametrage client

### Parametres ARM/Marketplace

| Parametre | Type | Usage |
|---|---|---|
| `adminUsername` | string | Compte Linux admin cree par Azure. |
| `adminPublicKey` | securestring | Acces SSH sans mot de passe. |
| `sshSourceIP` | string | Restriction NSG du port 22. |
| `vmSize` | string | Taille VM choisie. |
| `dataDiskSizeGB` | int | Taille du disque `/data`. |
| `wikiName` | string | Nom affiche du wiki. |
| `wikiHostName` | string | FQDN desire ou host Azure. |
| `wikiAdminEmail` | string | Email admin et contact Let's Encrypt. |
| `wikiAdminUser` | string | Nom du compte admin MediaWiki a creer. |
| `wikiAdminPassword` | securestring | Mot de passe admin MediaWiki genere/saisi au deploiement. |
| `databasePassword` | securestring | Secret SQL injecte au premier boot. |

Aucun de ces secrets ne doit etre present dans l'image Packer. Ils doivent etre fournis au runtime par ARM/cloud-init et stockes avec des permissions strictes.

### Sequence firstboot

```text
VM boot depuis image Marketplace
  cloud-init monte /data et ecrit /etc/smw/marketplace.env
  smw-firstboot.service demarre
    valide disque /data
    initialise /data/mysql, /data/uploads, /data/logs
    genere ou charge secrets runtime
    configure MySQL local
    configure LocalSettings.php
    execute maintenance/update.php
    configure Apache vhost et TLS self-signed
    tente Let's Encrypt seulement si DNS public pointe vers la VM
    redemarre php-fpm, mysql, apache
    ecrit /var/lib/smw/.firstboot-complete
    imprime resume operateur dans /var/log/smw-firstboot.log
```

### Idempotence

Le firstboot doit etre relancable sans detruire les donnees. Toute operation destructive doit verifier un marker et l'etat reel avant d'agir. Les mots de passe, `LocalSettings.php` et la base SQL ne doivent jamais etre regeneres silencieusement si un wiki existe deja.

## 8. Securite et certification Marketplace

### Surface reseau

| Port | Exposition | Decision |
|---:|---|---|
| 443 | Public | Acces principal MediaWiki/SMW. |
| 80 | Public | Redirection HTTPS et validation ACME si Let's Encrypt. |
| 22 | Restreint | SSH par cle uniquement, source IP limitee ou Bastion. |
| 3306 | Interdit public | SQL en loopback uniquement. |
| PHP-FPM | Interdit public | Socket Unix ou loopback uniquement. |

### Hardening obligatoire

- SSH: `PasswordAuthentication no`, `PermitRootLogin no`, `X11Forwarding no`, `ClientAliveInterval` conforme aux exigences Microsoft.
- TLS: TLS 1.2+ uniquement, suites modernes, HSTS une fois domaine stable.
- OS: mises a jour avant generalisation, aucune CVE critique connue au moment de la soumission.
- Agent Azure: `walinuxagent` et `cloud-init` installes et operationnels.
- Secrets: aucun secret de build, aucune cle SSH de build, aucun mot de passe par defaut.
- Logs/historique: nettoyage avant capture image.
- UFW et NSG: defense en profondeur; les services internes restent inaccessibles meme si le NSG est mal configure.

### Validation avant soumission

```text
packer validate
packer build
vm-test-create depuis Compute Gallery
smoke tests HTTP/TLS/SSH
verification Special:Version
verification maintenance/update.php sans erreur
verification ports exposes
AMAT / certification tests Microsoft
publication Partner Center en preview audience
```

## 9. Observabilite, backup et exploitation

### Logs

- `/var/log/smw-install.log`: log build-time Packer.
- `/var/log/smw-firstboot.log`: log runtime premier demarrage.
- `/var/log/apache2/`: acces et erreurs web.
- `/var/log/php8.2/`: PHP 8.2-FPM.
- `/data/logs/`: cible recommandee pour journaux applicatifs persistants si retenue.

### Sauvegarde

MVP recommande:

- Data disk separe pour faciliter snapshots Azure.
- Script `smw-backup.sh` futur: dump SQL + archive uploads + copie de `LocalSettings.php` nettoyee des secrets publics.
- Documentation Azure Backup: sauvegarde VM ou disque selon plan client.

### Monitoring

- Azure Monitor Agent compatible via VM extensions.
- Health check local: HTTPS, PHP-FPM, SQL, presence de SMW dans `Special:Version` ou test maintenance equivalent.
- Alertes futures: espace disque `/data`, statut Apache/PHP-FPM/MySQL, expiration certificat TLS.

## 10. Publication Marketplace et GTM

### Artefacts Partner Center

| Artefact | Contenu attendu |
|---|---|
| Offer setup | Offer ID stable, alias interne, publisher correct. |
| Properties | Categories, industries, legal, privacy policy. |
| Offer listing | Nom clair, resume court, description orientee valeur, liens docs. |
| Plans | Plan standard unique pour MVP; versions futures par variante supportee. |
| Technical configuration | Reference Compute Gallery accessible par Partner Center. |
| Preview audience | Comptes de validation avant publication publique. |
| Lead management | Referrals Partner Center ou CRM optionnel. |

### Bonnes pratiques GTM a appliquer

- Le nom de l'offre doit contenir les mots-cles utiles: Semantic MediaWiki, Knowledge Base, Azure.
- Les premieres phrases doivent expliquer la valeur, pas seulement la pile technique.
- Fournir captures 1280 x 720 montrant l'accueil MediaWiki, `Special:Version` avec SMW, et un exemple de page/requete semantique.
- Fournir un guide post-deploiement public: configuration domaine, remplacement TLS, creation admin, sauvegarde, mise a jour.
- Utiliser des URL de campagne avec `ocid` et `utm_*` pour mesurer les efforts de promotion.

## 11. Plans et evolutions

### MVP - Plan `standard`

- Une VM Ubuntu 22.04 LTS Gen2.
- Apache 2.4 + PHP 8.2-FPM.
- MediaWiki 1.43.x + SMW 6.0.1 installe par Composer.
- SQLStore local.
- MySQL 8.x local.
- Data disk `/data`.
- TLS self-signed + option Let's Encrypt si DNS valide.
- Hardening Marketplace.
- Documentation post-deploiement.

### Evolutions possibles

| Evolution | Precondition | Raison |
|---|---|---|
| Azure Database for MySQL | ARM plus complexe, cout additionnel | Separation compute/data et meilleure exploitation production. |
| Azure Blob uploads | Extension/config MediaWiki validee | Stockage durable et scalable des fichiers. |
| ElasticStore | Besoin recherche/performance justifie | Moteur documente par SMW mais ajoute Elasticsearch. |
| SPARQLStore | Cas linked-data avance | Necessite triple store externe et support operationnel plus lourd. |
| Microsoft Entra ID SSO | ADR 302 implemente | Authentification entreprise. |
| Managed Application | Besoin d'operation publisher | Plus de controle, mais complexite Marketplace superieure. |

## 12. Backlog technique recommande

1. Corriger les incoherences ADR heritees de DSpace: references a Nginx/Tomcat/Solr/PostgreSQL dans les ADR SMW lorsque non applicables.
2. Ajouter `docs/architecture/README.md` ou lier ce document depuis [README.md](../../README.md).
3. Creer la structure `packer/` conforme ADR 617.
4. Definir les variables versions dans un fichier unique: PHP, MediaWiki, SMW, MySQL/MariaDB, Ubuntu.
5. Implementer les provisioners 01 a 09 avec logs et validations locales.
6. Implementer `arm/mainTemplate.json` et `arm/createUIDefinition.json`.
7. Ajouter tests smoke/e2e: HTTPS, SSH, ports, `Special:Version`, update maintenance, firstboot idempotent.
8. Rediger `docs/marketplace/listing.md` et `docs/marketplace/plan-standard.md` en s'inspirant de DSpace.
9. Valider Compute Gallery permissions Partner Center.
10. Publier en preview audience avant soumission publique.

## 13. Definition of done architecture

L'architecture est consideree implementee lorsque:

- Un build Packer cree une image versionnee dans Azure Compute Gallery.
- Une VM de test deployee depuis cette image termine son firstboot sans intervention manuelle.
- MediaWiki est accessible en HTTPS.
- SMW apparait comme extension active et `maintenance/update.php` s'execute sans erreur.
- MySQL/PHP-FPM ne sont pas exposes publiquement.
- Aucun secret de build n'est present dans l'image generalisee.
- Les tests Marketplace/AMAT passent sur l'image candidate.
- Le listing Partner Center, le plan, les captures et la documentation post-deploiement sont prets pour preview audience.
