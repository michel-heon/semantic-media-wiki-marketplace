# Récits utilisateur — SMW Azure Marketplace

**Objet** : Elaboration complète des 36 récits utilisateur issus des 6 épopées Scrum du projet.  
Chaque récit est nécessaire à la fermeture de son épopée et suffisant (pas de gold-plating).  
**Références** : [epics.md](epics.md) · [personas.md](personas.md) · ADR-001 (versions canoniques)

**Versions canoniques (ADR-001 — ne jamais inventer d'autres numéros)** :  
Ubuntu 22.04 LTS · PHP 8.2-FPM · MySQL 8.x · MediaWiki 1.43.x · SMW 6.0.1 · Apache 2.4 · Packer 1.11+

---

## Vue d'ensemble du backlog

| ID | Titre court | Épopée | Persona | Priorité |
|----|-------------|--------|---------|----------|
| US-01.1 | Variables Packer centralisées | EPIC-01 | P1 Thomas | Must |
| US-01.2 | Validation HCL2 sans build | EPIC-01 | P1 Thomas | Must |
| US-01.3 | Build et publication gallery | EPIC-01 | P1 Thomas | Must |
| US-01.4 | Cache APT/Composer Blob Storage | EPIC-01 | P1 Thomas | Must |
| US-01.5 | Nommage versionné gallery | EPIC-01 | P1 Thomas | Must |
| US-01.6 | Journalisation provisioners | EPIC-01 | P1 Thomas | Must |
| US-02.1 | Paramètres ARM au déploiement | EPIC-02 | P1 Thomas | Must |
| US-02.2 | Wiki HTTPS au premier boot | EPIC-02 | Client | Must |
| US-02.3 | Idempotence firstboot.service | EPIC-02 | P1 Thomas | Must |
| US-02.4 | Aucun secret dans l'image | EPIC-02 | P1 Thomas | Must |
| US-02.5 | Log firstboot lisible | EPIC-02 | Client | Should |
| US-02.6 | Workflow itération rapide dev | EPIC-02 | P1 Thomas | Should |
| US-03.1 | Rapport 15 contrôles AMAT | EPIC-03 | P3 Félix | Must |
| US-03.2 | Hardening SSH automatisé | EPIC-03 | P3 Félix | Must |
| US-03.3 | TLS 1.2+ vérifié par tests | EPIC-03 | P3 Félix | Must |
| US-03.4 | waagent deprovision dernière étape | EPIC-03 | P3 Félix | Must |
| US-03.5 | Traçabilité non-conformités AMAT | EPIC-03 | P1 Thomas | Should |
| US-03.6 | Rapport certif avant Preview | EPIC-03 | P2 Nadia | Must |
| US-04.1 | Création offre Partner Center | EPIC-04 | P2 Nadia | Must |
| US-04.2 | Permissions gallery Compute Reader | EPIC-04 | P2 Nadia | Must |
| US-04.3 | Plan technique lié image certifiée | EPIC-04 | P2 Nadia | Must |
| US-04.4 | Runbook publication pas-à-pas | EPIC-04 | P2 Nadia | Must |
| US-04.5 | Plan tarifaire BYOL/Free GPL-2.0 | EPIC-04 | P5 Jérôme | Must |
| US-04.6 | Audience Preview restreinte | EPIC-04 | P2 Nadia | Must |
| US-05.1 | Description longue HTML conforme | EPIC-05 | P4 Claire | Must |
| US-05.2 | 4 logos PNG formats requis | EPIC-05 | P4 Claire | Must |
| US-05.3 | 3 screenshots 1280×720 annotés | EPIC-05 | P4 Claire | Must |
| US-05.4 | Guide post-déploiement public | EPIC-05 | P4 Claire | Must |
| US-05.5 | Validation listing PO | EPIC-05 | P5 Jérôme | Must |
| US-05.6 | Checklist mise à jour listing | EPIC-05 | P5 Jérôme | Should |
| US-06.1 | Soumission Preview et validation | EPIC-06 | P2 Nadia | Must |
| US-06.2 | Smoke tests VM Preview | EPIC-06 | P1 Thomas | Must |
| US-06.3 | Soumission Live | EPIC-06 | P2 Nadia | Must |
| US-06.4 | Dashboard Partner Center partagé | EPIC-06 | P5 Jérôme | Should |
| US-06.5 | URLs campagne ocid/utm_* | EPIC-06 | P5 Jérôme | Should |
| US-06.6 | Runbook gestion des rejets | EPIC-06 | P2 Nadia | Must |

---

## EPIC-01 — Pipeline de build Packer

**Valeur** : Produire une image VM Azure reproductible, versionnée et publiée dans `galSMWMarketplace`.

---

### US-01.1 — Variables Packer centralisées

**Épopée** : EPIC-01 | **Persona** : P1 Thomas R. — DevOps Image Builder | **Priorité** : Must

> En tant que **DevOps Image Builder**, je veux un fichier `packer/variables.pkr.hcl` centralisant toutes les versions épinglées afin d'éviter les régressions causées par des changements de versions upstream.

#### Critères d'acceptation

- [ ] `packer/variables.pkr.hcl` déclare les variables `smw_version`, `mediawiki_version`, `php_version`, `mysql_version`, `ubuntu_version` avec leurs valeurs par défaut canoniques (SMW 6.0.1, MediaWiki 1.43.x, PHP 8.2, MySQL 8.x, Ubuntu 22.04 LTS).
- [ ] Aucune version n'est hardcodée dans les fichiers provisioners `01-*.sh` à `09-*.sh` ; toutes les références passent par les variables Packer via l'interpolation `${var.xxx}`.
- [ ] Un check automatique `make vm-check-versions` échoue (code retour non-nul) si un provisioner contient une version hardcodée (grep pattern pour les numéros de version).
- [ ] Le fichier `packer/smw-vm.pkr.hcl` référence le bloc `variable` depuis `variables.pkr.hcl`.

#### Tâches

- [ ] Créer `packer/variables.pkr.hcl` avec les variables de version et leurs valeurs par défaut.
- [ ] Refactoriser les provisioners pour utiliser `${var.xxx}` ou recevoir la variable via l'environnement (`PKR_VAR_xxx`).
- [ ] Ajouter la cible `vm-check-versions` dans le Makefile avec un `grep` de guard.

#### Dépendances

- Dépend de : — (première US, pas de prérequis)
- Bloque : US-01.2, US-01.3, US-01.6

**ADR(s)** : [ADR-001](../adr/001-META-definition-projet-smw-marketplace.md) · [ADR-617](../adr/617-DEVOPS-packer-outil-construction-images-vm.md)

---

### US-01.2 — Validation HCL2 sans build complet

**Épopée** : EPIC-01 | **Persona** : P1 Thomas R. | **Priorité** : Must

> En tant que **DevOps Image Builder**, je veux exécuter `make vm-validate` pour valider le template HCL2 sans lancer un build Azure afin de détecter les erreurs de syntaxe avant de consommer du crédit cloud.

#### Critères d'acceptation

- [ ] `make vm-validate` exécute `packer validate packer/smw-vm.pkr.hcl` et se termine en moins de 30 secondes.
- [ ] En cas d'erreur de syntaxe ou de variable non définie, la commande retourne un code non-nul avec un message d'erreur lisible sur stdout.
- [ ] La validation s'effectue sans connexion Azure active (pas d'appel ARM dans la phase validate).
- [ ] La cible `vm-validate` est documentée dans le README racine du projet.
- [ ] La CI (si présente) appelle `make vm-validate` avant `make vm-build`.

#### Tâches

- [ ] Ajouter la cible `vm-validate` dans le Makefile : `packer validate -var-file=packer/variables.pkr.hcl packer/smw-vm.pkr.hcl`.
- [ ] Documenter la cible dans le README racine.

#### Dépendances

- Dépend de : US-01.1 (variables déclarées)
- Bloque : US-01.3

**ADR(s)** : [ADR-602](../adr/602-DEVOPS-makefile-orchestrateur.md) · [ADR-617](../adr/617-DEVOPS-packer-outil-construction-images-vm.md)

---

### US-01.3 — Build et publication dans Azure Compute Gallery

**Épopée** : EPIC-01 | **Persona** : P1 Thomas R. | **Priorité** : Must

> En tant que **DevOps Image Builder**, je veux exécuter `make vm-build` et obtenir une image versionnée publiée dans `galSMWMarketplace` afin de disposer d'une image prête à la certification AMAT en moins de 20 min (avec cache).

#### Critères d'acceptation

- [ ] `make vm-build` exécute `packer build -var-file=packer/variables.pkr.hcl packer/smw-vm.pkr.hcl`.
- [ ] L'image est publiée dans `galSMWMarketplace/smw-knowledge-base/{smw_version}.{YYYYMMDD}` (format ADR-001).
- [ ] La gallery `galSMWMarketplace` est dans le tenant Entra ID `aba0984a`.
- [ ] La VM de build utilise au minimum `Standard_D2s_v3`.
- [ ] La taille du disque OS est comprise entre 30 et 50 GB.
- [ ] Le build avec cache APT/Composer (US-01.4) se termine en moins de 20 min.
- [ ] Le build sans cache se termine en moins de 40 min.
- [ ] L'image est marquée `generalized = true` dans les métadonnées Azure.

#### Tâches

- [ ] Créer `packer/smw-vm.pkr.hcl` avec le bloc `source "azure-arm"` configurant la gallery destination.
- [ ] Configurer `shared_image_gallery_destination` avec `gallery_name`, `image_name`, `image_version`.
- [ ] Ajouter la cible `vm-build` dans le Makefile.
- [ ] Vérifier le nommage de version post-build via `az sig image-version list`.

#### Dépendances

- Dépend de : US-01.1 (variables), US-01.2 (validation OK), US-01.4 (cache disponible)
- Bloque : US-03.1, US-04.3, EPIC-02 (image cible pour dev VM)

**ADR(s)** : [ADR-200](../adr/200-INFRA-azure-infrastructure-vm-offer.md) · [ADR-617](../adr/617-DEVOPS-packer-outil-construction-images-vm.md)

---

### US-01.4 — Cache APT/Composer sur Azure Blob Storage

**Épopée** : EPIC-01 | **Persona** : P1 Thomas R. | **Priorité** : Must

> En tant que **DevOps Image Builder**, je veux un cache APT et Composer sur Azure Blob Storage (ADR-616) afin de réduire le temps de build et d'éviter les défaillances de dépendances upstream.

#### Critères d'acceptation

- [ ] Un conteneur Azure Blob Storage est configuré pour stocker le cache des paquets APT et des dépendances Composer.
- [ ] Les provisioners `02-install-php.sh`, `03-install-mysql.sh`, `04-install-mediawiki.sh` utilisent le cache Blob en lecture avant de télécharger depuis Internet.
- [ ] Un cache hit réduit la durée du build d'au moins 50 % comparé à un build sans cache.
- [ ] La cible `make cache-warm` déclenche un build "à vide" pour pré-remplir le cache après une mise à jour des versions dans `variables.pkr.hcl`.
- [ ] La cible `make cache-invalidate` vide le cache Blob pour une version donnée.

#### Tâches

- [ ] Créer le conteneur Blob Storage dédié au cache (nom, access policy SAS).
- [ ] Modifier les provisioners pour utiliser `azcopy` ou `az storage blob download` en début de provisioner.
- [ ] Ajouter les cibles `cache-warm` et `cache-invalidate` dans le Makefile.
- [ ] Documenter la procédure d'invalidation lors d'un changement de version.

#### Dépendances

- Dépend de : US-01.1 (versions centralisées)
- Bloque : US-01.3 (build optimisé)

**ADR(s)** : [ADR-616](../adr/616-DEVOPS-blob-storage-cache-packages-packer.md)

---

### US-01.5 — Nommage versionné dans Azure Compute Gallery

**Épopée** : EPIC-01 | **Persona** : P1 Thomas R. | **Priorité** : Must

> En tant que **DevOps Image Builder**, je veux que chaque image publiée dans `galSMWMarketplace` suive le format `{smw_version}.{YYYYMMDD}` afin de respecter ADR-001 §Nomenclature et de tracer chaque build avec précision.

#### Critères d'acceptation

- [ ] La version de chaque image dans la gallery suit le format `{smw_version}.{YYYYMMDD}` (ex. : `6.0.1.20260511`), où la date est celle du jour du build en UTC.
- [ ] Deux builds le même jour produisent deux versions distinctes (suffixe `-N` ou horodatage `HHMMSS`).
- [ ] La cible `make gallery-list` affiche la liste des versions présentes dans la gallery pour l'image `smw-knowledge-base`.
- [ ] Un pattern de validation par expression régulière est inclus dans le Makefile pour vérifier la conformité avant soumission Partner Center.

#### Tâches

- [ ] Configurer la version dynamique dans `smw-vm.pkr.hcl` avec une variable locale `local { image_version = ... }` construite depuis `var.smw_version` et la date du jour.
- [ ] Ajouter la cible `make gallery-list` dans le Makefile.
- [ ] Ajouter un check de format (regex) dans la cible `make vm-build`.

#### Dépendances

- Dépend de : US-01.3 (build gallery opérationnel)
- Bloque : US-04.3 (plan technique référence la version)

**ADR(s)** : [ADR-001](../adr/001-META-definition-projet-smw-marketplace.md) · [ADR-603](../adr/603-DEVOPS-git-workflow-et-strategie-versioning.md)

---

### US-01.6 — Journalisation des provisioners

**Épopée** : EPIC-01 | **Persona** : P1 Thomas R. | **Priorité** : Must

> En tant que **DevOps Image Builder**, je veux que les provisioners 01–09 journalisent leur exécution dans `/var/log/smw-install.log` afin de diagnostiquer les échecs de build sans rejouer tout le pipeline.

#### Critères d'acceptation

- [ ] Chaque script provisioner (`01-*.sh` à `09-*.sh`) redirige stdout et stderr vers `/var/log/smw-install.log` en mode append avec horodatage.
- [ ] Un en-tête lisible `=== PROVISIONER 01: <nom> — $(date --utc) ===` est écrit en début de chaque provisioner.
- [ ] En cas d'échec (code retour non-nul), Packer affiche les 50 dernières lignes du log dans la sortie build.
- [ ] Le fichier `/var/log/smw-install.log` est supprimé par `09-cleanup-generalize.sh` avant `waagent deprovision`.
- [ ] Le log est consultable pendant le build en SSH sur la VM Packer (phase de build, pas l'image finale).

#### Tâches

- [ ] Ajouter en début de chaque provisioner : `exec > >(tee -a /var/log/smw-install.log) 2>&1` et le banner horodaté.
- [ ] Vérifier que `09-cleanup-generalize.sh` supprime `/var/log/smw-install.log` avant la déprovision.
- [ ] Configurer Packer pour afficher les erreurs du log en cas d'échec (option `-on-error=ask` ou post-processor).

#### Dépendances

- Dépend de : US-01.1 (structure provisioners en place)
- Bloque : US-03.1 (smoke tests lisent les logs)

**ADR(s)** : [ADR-617](../adr/617-DEVOPS-packer-outil-construction-images-vm.md) · [ADR-600](../adr/600-DEVOPS-bootstrap-configuration-management.md)

---

## EPIC-02 — Runtime client — firstboot & ARM

**Valeur** : Le client déploie une VM depuis le Marketplace et obtient un wiki SMW configuré, sécurisé et opérationnel sans intervention manuelle.

---

### US-02.1 — Paramètres ARM injectés au déploiement

**Épopée** : EPIC-02 | **Persona** : P1 Thomas R. + Client Azure | **Priorité** : Must

> En tant que **client Azure**, je veux renseigner les paramètres du wiki (nom, domaine, admin, mot de passe) dans le formulaire de déploiement ARM afin de configurer mon wiki entièrement depuis le Portail Azure, sans SSH post-déploiement.

#### Critères d'acceptation

- [ ] `arm/createUIDefinition.json` expose les champs : `wikiName`, `wikiHostName`, `wikiAdminUser`, `wikiAdminEmail`, `wikiAdminPassword`, `databasePassword`, `adminUsername`, `adminPublicKey`, `sshSourceIP`, `vmSize`, `dataDiskSizeGB`.
- [ ] Les champs `wikiAdminPassword` et `databasePassword` utilisent `Microsoft.Common.PasswordBox` (valeurs masquées, non exportées en clair).
- [ ] Les contraintes de validation sont définies (longueur min/max, regex URL pour `wikiHostName`).
- [ ] `arm/mainTemplate.json` mappe tous les paramètres vers `customData` (base64-encodé) transmis au premier boot.
- [ ] Le bouton "Deploy to Azure" depuis le README fonctionne et affiche le formulaire correct sur portal.azure.com.
- [ ] Aucun paramètre sensible ne figure dans les logs ARM (Deployment outputs).

#### Tâches

- [ ] Créer `arm/createUIDefinition.json` avec les blocs `parameters`, `steps`, `outputs` complets.
- [ ] Créer `arm/mainTemplate.json` avec les sections `parameters`, `variables`, `resources` (VM, NIC, NSG, disque de données, IP publique).
- [ ] Configurer `customData` en base64 de l'ensemble des paramètres du wiki (format JSON ou shell env).
- [ ] Tester le formulaire Portal via le lien "Deploy to Azure" sur un tenant de test.

#### Dépendances

- Dépend de : US-01.3 (image dans la gallery pour la référence ARM)
- Bloque : US-02.2, US-02.3, US-02.4

**ADR(s)** : [ADR-200](../adr/200-INFRA-azure-infrastructure-vm-offer.md) · [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)

---

### US-02.2 — Wiki accessible en HTTPS dès le premier boot

**Épopée** : EPIC-02 | **Persona** : Client Azure | **Priorité** : Must

> En tant que **client Azure**, je veux que mon wiki SMW soit accessible à `https://{wikiHostName}/` dans les 10 min suivant le déploiement ARM afin de démarrer sans intervention manuelle.

#### Critères d'acceptation

- [ ] `https://{wikiHostName}/` retourne HTTP 200 dans les 10 min suivant la fin du déploiement ARM (mesuré depuis l'extérieur).
- [ ] HTTP port 80 redirige vers HTTPS avec code 301.
- [ ] Le certificat TLS self-signed est généré au premier boot avec `CN={wikiHostName}` et une durée de validité de 1 an.
- [ ] `Special:Version` est accessible et affiche MediaWiki 1.43.x avec Semantic MediaWiki 6.0.1.
- [ ] `smw-firstboot.service` est en état `inactive (dead)` (exited 0) dans `systemctl status smw-firstboot` après le premier boot.
- [ ] Le port 3306 (MySQL) n'est accessible que depuis `127.0.0.1`.

#### Tâches

- [ ] Écrire `firstboot.sh` : lecture `customData`, génération certificat TLS self-signed via `openssl req`, configuration VirtualHost Apache, initialisation DB MySQL, exécution `php maintenance/install.php`, exécution `php maintenance/update.php`.
- [ ] Créer `smw-firstboot.service` (systemd, `Type=oneshot`, `RemainAfterExit=yes`, `ExecStart=/usr/local/bin/firstboot.sh`).
- [ ] Activer le service dans le provisioner `05-configure-service.sh` (ou équivalent) via `systemctl enable smw-firstboot`.
- [ ] Tester le scénario complet sur une VM Azure déployée depuis la gallery.

#### Dépendances

- Dépend de : US-02.1 (paramètres ARM), US-01.3 (image en gallery)
- Bloque : US-02.3, US-02.5, US-06.2

**ADR(s)** : [ADR-200](../adr/200-INFRA-azure-infrastructure-vm-offer.md) · [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) · [ADR-302](../adr/302-SEC-sso-microsoft-entra-id.md)

---

### US-02.3 — Idempotence de smw-firstboot.service

**Épopée** : EPIC-02 | **Persona** : P1 Thomas R. | **Priorité** : Must

> En tant que **DevOps Image Builder**, je veux que `smw-firstboot.service` soit idempotent afin de pouvoir relancer le service après un redémarrage ou une erreur partielle sans détruire un wiki existant.

#### Critères d'acceptation

- [ ] Si le fichier sentinelle `/var/lib/smw-firstboot.done` existe, `firstboot.sh` se termine immédiatement avec code 0 sans exécuter aucune action.
- [ ] Une deuxième exécution de `firstboot.sh` ne modifie pas `LocalSettings.php`, ne réinitialise pas la base de données, ne régénère pas le certificat TLS.
- [ ] Le fichier `/var/lib/smw-firstboot.done` est créé uniquement en fin de `firstboot.sh`, après succès complet (pas en cas d'erreur intermédiaire).
- [ ] L'idempotence est couverte par un test dans `make vm-test` : deux exécutions consécutives sur une VM de dev produisent le même état final.

#### Tâches

- [ ] Ajouter en début de `firstboot.sh` : `[ -f /var/lib/smw-firstboot.done ] && exit 0`.
- [ ] Créer `/var/lib/smw-firstboot.done` en toute dernière ligne de `firstboot.sh` (succès uniquement).
- [ ] Ajouter un test d'idempotence dans le script `scripts/validate/amat-check.sh` ou dans un script de test dédié.

#### Dépendances

- Dépend de : US-02.2 (firstboot.sh opérationnel)
- Bloque : US-03.1 (les tests supposent un firstboot idempotent)

**ADR(s)** : [ADR-614](../adr/614-DEVOPS-dev-vm-iteration-workflow.md)

---

### US-02.4 — Aucun secret dans l'image Packer

**Épopée** : EPIC-02 | **Persona** : P1 Thomas R. | **Priorité** : Must

> En tant que **DevOps Image Builder**, je veux qu'aucun secret ne soit présent dans l'image Packer finalisée afin de respecter les exigences Marketplace (aucun credential par défaut, ADR-300).

#### Critères d'acceptation

- [ ] `LocalSettings.php` n'est pas présent dans l'image ; il est généré uniquement au premier boot.
- [ ] Aucun mot de passe MySQL, clé API ou credential n'est présent dans les fichiers provisioners écrits sur disque.
- [ ] `grep -r "password\|secret\|key" /etc/ /root/ /home/` sur l'image généralisée ne retourne aucun credential réel.
- [ ] `09-cleanup-generalize.sh` supprime `~/.bash_history`, `/root/.bash_history`, `/tmp/*`, les clés SSH utilisées pendant le build, et `/var/log/smw-install.log`.
- [ ] L'image passe le contrôle AMAT "no default credentials" (US-03.1, contrôle #CRED-01 d'ADR-300).

#### Tâches

- [ ] Auditer chaque provisioner (`01-*.sh` à `09-*.sh`) pour toute écriture de secret sur disque.
- [ ] Écrire les commandes de nettoyage dans `09-cleanup-generalize.sh`.
- [ ] Ajouter un test dans `scripts/validate/amat-check.sh` vérifiant l'absence de credentials dans l'image.

#### Dépendances

- Dépend de : US-01.6 (journalisation provisioners, nettoyage log)
- Bloque : US-03.4 (waagent déprovision suppose cleanup fait)

**ADR(s)** : [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) · [ADR-300-image](../adr/300-SEC-securite-image-vm.md)

---

### US-02.5 — Log firstboot lisible par l'admin

**Épopée** : EPIC-02 | **Persona** : Client Azure | **Priorité** : Should

> En tant que **client Azure**, je veux un log lisible à `/var/log/smw-firstboot.log` afin de diagnostiquer un premier boot en échec sans nécessiter l'accès à la console série Azure.

#### Critères d'acceptation

- [ ] `/var/log/smw-firstboot.log` est créé et rempli durant l'exécution de `firstboot.sh`.
- [ ] Chaque étape (lecture `customData`, génération certificat, config Apache, init DB, install MediaWiki, install SMW) est horodatée et identifiée dans le log.
- [ ] En cas d'erreur, le log contient le message d'erreur complet et `firstboot.sh` sort avec un code non-nul.
- [ ] Le fichier est lisible par l'utilisateur admin SSH (`chmod 644`, owner `root`).
- [ ] Le log n'est **pas** supprimé par `09-cleanup-generalize.sh` (il est créé au runtime, pas au build).
- [ ] Le chemin du log est mentionné dans le guide post-déploiement (US-05.4).

#### Tâches

- [ ] Ajouter le logging horodaté dans `firstboot.sh` : `echo "[$(date --utc)] STEP: <nom>" >> /var/log/smw-firstboot.log`.
- [ ] S'assurer que les erreurs sont capturées avec `set -e` et un `trap ERR` qui écrit dans le log.
- [ ] Documenter le chemin du log dans `docs/` (US-05.4).

#### Dépendances

- Dépend de : US-02.2 (firstboot.sh opérationnel)
- Bloque : US-05.4 (guide post-déploiement)

**ADR(s)** : [ADR-614](../adr/614-DEVOPS-dev-vm-iteration-workflow.md)

---

### US-02.6 — Workflow d'itération rapide sans rebuild Packer

**Épopée** : EPIC-02 | **Persona** : P1 Thomas R. | **Priorité** : Should

> En tant que **DevOps Image Builder**, je veux un workflow `make vm-dev-create` / `make provision-push` (ADR-614) afin d'itérer sur les scripts firstboot sans relancer un build Packer complet (40 min).

#### Critères d'acceptation

- [ ] `make vm-dev-create` déploie une VM Azure depuis la dernière image versionnée de `galSMWMarketplace` dans un groupe de ressources de dev préfixé `dev-smw-` (ADR-601).
- [ ] `make provision-push` copie les fichiers scripts locaux modifiés sur la VM de dev via `scp` et les exécute via `ssh`.
- [ ] Le cycle complet (modifier un script → `make provision-push` → vérifier) prend moins de 2 min.
- [ ] `make vm-dev-delete` supprime proprement la VM de dev et ses ressources associées.
- [ ] Les VMs de dev ne persistent pas entre les sessions de travail (nettoyage explicite requis).

#### Tâches

- [ ] Ajouter les cibles `vm-dev-create`, `provision-push`, `vm-dev-delete` dans le Makefile.
- [ ] Documenter le workflow dans `docs/adr/614-DEVOPS-dev-vm-iteration-workflow.md`.

#### Dépendances

- Dépend de : US-01.3 (image dans la gallery)
- Bloque : — (facilite US-02.2, US-02.3, non bloquant)

**ADR(s)** : [ADR-614](../adr/614-DEVOPS-dev-vm-iteration-workflow.md) · [ADR-602](../adr/602-DEVOPS-makefile-orchestrateur.md)

---

## EPIC-03 — Sécurité, hardening et certification AMAT

**Valeur** : L'image passe la certification AMAT de Microsoft et ne contient aucune vulnérabilité bloquante à la soumission Partner Center.

---

### US-03.1 — Rapport automatique des 15 contrôles AMAT

**Épopée** : EPIC-03 | **Persona** : P3 Félix M. — Ingénieur Certification | **Priorité** : Must

> En tant qu'**Ingénieur Certification**, je veux exécuter `make vm-test` et obtenir un rapport complet des 15 contrôles AMAT afin de signer l'image avant sa soumission dans Partner Center.

#### Critères d'acceptation

- [ ] `make vm-test` s'exécute en SSH sur une VM déployée depuis l'image gallery (pas en local sur le host).
- [ ] Le rapport liste les 15 contrôles définis dans ADR-300 avec le statut `[PASS]` ou `[FAIL]` pour chacun.
- [ ] Tout contrôle en `[FAIL]` produit un code retour non-nul bloquant la soumission.
- [ ] Le rapport est sauvegardé automatiquement dans `docs/certification/report-{YYYYMMDD}.txt`.
- [ ] Le rapport identifie clairement la version de l'image testée (`smw_version.YYYYMMDD`).
- [ ] Un run sans aucun `[FAIL]` est requis pour valider la DoD d'EPIC-03.

#### Tâches

- [ ] Créer `scripts/validate/amat-check.sh` implémentant les 15 contrôles (cf. ADR-300 §Tableau des tests).
- [ ] Ajouter la cible `vm-test` dans le Makefile (SSH sur la VM cible passée en paramètre ou variable d'env).
- [ ] Créer le dossier `docs/certification/` avec un `.gitkeep`.
- [ ] Ajouter une redirection de sortie vers `docs/certification/report-{YYYYMMDD}.txt` dans la cible `vm-test`.

#### Dépendances

- Dépend de : US-01.3 (image dans la gallery), US-02.2 (firstboot opérationnel), US-02.4 (pas de secrets)
- Bloque : US-03.6, US-04.3

**ADR(s)** : [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) · [ADR-613](../adr/613-DEVOPS-provisioner-architecture-validation.md)

---

### US-03.2 — Hardening SSH automatisé et vérifié

**Épopée** : EPIC-03 | **Persona** : P3 Félix M. | **Priorité** : Must

> En tant qu'**Ingénieur Certification**, je veux que `PasswordAuthentication no` et `PermitRootLogin no` soient configurés et vérifiés automatiquement afin de garantir le hardening SSH sur chaque image sans vérification manuelle.

#### Critères d'acceptation

- [ ] `08-security-harden.sh` crée `/etc/ssh/sshd_config.d/smw-hardening.conf` avec `PasswordAuthentication no`, `PermitRootLogin no`, `Protocol 2`.
- [ ] La configuration est dans un fichier drop-in pour survivre à un `apt upgrade openssh-server` sans écrasement.
- [ ] Le pare-feu UFW est configuré pour restreindre le port 22 à l'IP source du paramètre ARM `sshSourceIP`.
- [ ] `make vm-test` vérifie les paramètres SSH (contrôles AMAT #SSH-01 et #SSH-02 d'ADR-300) et retourne `[PASS]` pour les deux.
- [ ] Une tentative de connexion SSH par mot de passe échoue (`Permission denied (publickey)`).

#### Tâches

- [ ] Créer `/etc/ssh/sshd_config.d/smw-hardening.conf` dans `08-security-harden.sh`.
- [ ] Configurer UFW (`ufw allow from {sshSourceIP} to any port 22`, `ufw deny 22`, `ufw enable`) dans `08-security-harden.sh`.
- [ ] Ajouter les contrôles SSH dans `scripts/validate/amat-check.sh`.

#### Dépendances

- Dépend de : US-02.1 (paramètre `sshSourceIP` disponible)
- Bloque : US-03.1 (contrôles SSH dans le rapport AMAT)

**ADR(s)** : [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) · [ADR-300-image](../adr/300-SEC-securite-image-vm.md)

---

### US-03.3 — TLS 1.2+ vérifié par tests automatiques

**Épopée** : EPIC-03 | **Persona** : P3 Félix M. | **Priorité** : Must

> En tant qu'**Ingénieur Certification**, je veux que TLS 1.0 et TLS 1.1 soient désactivés dans Apache et que `openssl s_client` confirme TLS 1.2+ afin de respecter les exigences Microsoft (ADR-300).

#### Critères d'acceptation

- [ ] La configuration Apache (`/etc/apache2/mods-enabled/ssl.conf` ou `smw-ssl.conf`) définit `SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1`.
- [ ] `SSLCipherSuite` exclut les suites faibles (RC4, DES, 3DES, NULL, EXPORT).
- [ ] `openssl s_client -connect localhost:443 -tls1` retourne un code d'erreur non-nul (connexion refusée).
- [ ] `openssl s_client -connect localhost:443 -tls1_2` retourne code 0.
- [ ] Le contrôle TLS est inclus dans `make vm-test` et retourne `[PASS]`.
- [ ] La configuration Apache survit à `apt upgrade libssl-dev apache2` sans réinitialisation.

#### Tâches

- [ ] Configurer `SSLProtocol` et `SSLCipherSuite` dans `08-security-harden.sh`.
- [ ] Placer la configuration TLS dans un fichier drop-in Apache (`/etc/apache2/conf-available/smw-tls.conf`).
- [ ] Ajouter le test TLS dans `scripts/validate/amat-check.sh`.

#### Dépendances

- Dépend de : US-02.2 (Apache opérationnel avec TLS)
- Bloque : US-03.1 (contrôle TLS dans le rapport AMAT)

**ADR(s)** : [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) · [ADR-300-image](../adr/300-SEC-securite-image-vm.md)

---

### US-03.4 — `waagent -deprovision+user -force` en dernière étape

**Épopée** : EPIC-03 | **Persona** : P3 Félix M. | **Priorité** : Must

> En tant qu'**Ingénieur Certification**, je veux que `waagent -deprovision+user -force` soit la dernière commande exécutée dans `09-cleanup-generalize.sh` afin d'empêcher la soumission d'une image non généralisée.

#### Critères d'acceptation

- [ ] `09-cleanup-generalize.sh` exécute `waagent -deprovision+user -force` comme commande terminale (dernière ligne active du script).
- [ ] Aucune commande ni écriture de fichier ne suit `waagent deprovision` dans `09-cleanup-generalize.sh`.
- [ ] Un check `make vm-check-generalize` vérifie automatiquement que le script se termine par `waagent deprovision` (grep + code retour non-nul si absent).
- [ ] L'image publiée dans la gallery est marquée `OsState=Generalized` dans les métadonnées Azure (`az sig image-version show`).

#### Tâches

- [ ] Écrire `09-cleanup-generalize.sh` : nettoyage logs, historiques, clés SSH, fichiers temporaires, puis `waagent -deprovision+user -force` en dernière ligne.
- [ ] Ajouter la cible `vm-check-generalize` dans le Makefile.
- [ ] Vérifier le statut `OsState` de l'image dans la gallery après chaque build.

#### Dépendances

- Dépend de : US-02.4 (nettoyage des secrets dans cleanup)
- Bloque : US-03.1 (image doit être généralisée avant les tests AMAT)

**ADR(s)** : [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) · [ADR-617](../adr/617-DEVOPS-packer-outil-construction-images-vm.md)

---

### US-03.5 — Traçabilité des non-conformités AMAT vers Git

**Épopée** : EPIC-03 | **Persona** : P1 Thomas R. | **Priorité** : Should

> En tant que **DevOps Image Builder**, je veux que chaque non-conformité AMAT génère un message formaté référençant l'ADR concerné afin de créer des tickets Git traçables entre builds.

#### Critères d'acceptation

- [ ] Chaque contrôle `[FAIL]` dans `amat-check.sh` produit un message formaté : `[FAIL] CONTROL-XX: <description> (ADR-300 §<section>)`.
- [ ] Une template GitHub Issue `amat-remediation.md` existe dans `.github/ISSUE_TEMPLATE/` avec les champs : contrôle AMAT, description, image testée, étapes de remédiation, ADR de référence.
- [ ] Les issues AMAT créées depuis la template sont labellisées `amat` et `certification`.
- [ ] Le rapport `docs/certification/report-{YYYYMMDD}.txt` est commité dans Git lors du cycle de soumission Preview.

#### Tâches

- [ ] S'assurer que `amat-check.sh` produit des messages formatés avec références ADR.
- [ ] Créer `.github/ISSUE_TEMPLATE/amat-remediation.md`.
- [ ] Documenter la procédure de traçabilité dans le runbook (US-04.4).

#### Dépendances

- Dépend de : US-03.1 (rapport AMAT opérationnel)
- Bloque : US-03.6 (rapport doit être commité)

**ADR(s)** : [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md)

---

### US-03.6 — Rapport de certification disponible avant soumission Preview

**Épopée** : EPIC-03 | **Persona** : P2 Nadia C. — Responsable Partner Center | **Priorité** : Must

> En tant que **Responsable Partner Center**, je veux disposer d'un rapport de certification commité dans Git avant chaque soumission Preview afin de confirmer la conformité sans nécessiter un accès SSH à la VM.

#### Critères d'acceptation

- [ ] Le rapport `docs/certification/report-{YYYYMMDD}.txt` est commité dans le dépôt Git et référence la version de l'image certifiée (format `{smw_version}.{YYYYMMDD}`).
- [ ] Le rapport indique `ALL CONTROLS: PASS` pour les 15 contrôles AMAT.
- [ ] Le runbook de publication (US-04.4) référence explicitement ce rapport comme prérequis bloquant à la soumission Preview.
- [ ] Nadia peut lire le rapport dans le dépôt Git sans accès SSH.

#### Tâches

- [ ] Ajouter l'étape "commit rapport AMAT" dans le runbook de publication.
- [ ] Créer `docs/certification/README.md` expliquant la procédure de génération et de commit du rapport.

#### Dépendances

- Dépend de : US-03.1 (rapport généré), US-03.5 (traçabilité)
- Bloque : US-04.1 (soumission Preview présuppose certification OK)

**ADR(s)** : [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) · [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)

---

## EPIC-04 — Offre Partner Center et configuration technique

**Valeur** : L'offre Azure Marketplace est créée, configurée et prête à la soumission Preview avec l'image certifiée référencée.

---

### US-04.1 — Création de l'offre `smw-knowledge-base` dans Partner Center

**Épopée** : EPIC-04 | **Persona** : P2 Nadia C. | **Priorité** : Must

> En tant que **Responsable Partner Center**, je veux créer l'offre `smw-knowledge-base` dans Partner Center avant toute autre étape de configuration afin d'éviter une erreur irréversible sur `OFFER_ID` (ADR-800 : immutable après création).

#### Critères d'acceptation

- [ ] L'offre existe dans Partner Center avec exactement `OFFER_ID=smw-knowledge-base` (alphanumérique + tirets, max 50 chars, immutable).
- [ ] `PUBLISHER_ID=cotechnoe` et `OFFER_ALIAS=SMW Knowledge Base VM` sont configurés.
- [ ] Le type d'offre est "Azure Virtual Machine".
- [ ] L'offre est en état `Draft` après création.
- [ ] `OFFER_ID` et `PUBLISHER_ID` sont documentés et versionnés dans ADR-800.

#### Tâches

- [ ] Créer l'offre dans Partner Center (action manuelle, irréversible — nécessite validation Nadia + Jérôme avant exécution).
- [ ] Commiter une note de confirmation avec la date de création dans le runbook.
- [ ] Vérifier que `OFFER_ID` respecte la contrainte de format.

#### Dépendances

- Dépend de : US-03.6 (certification validée avant création offre)
- Bloque : US-04.2, US-04.3, US-04.4, US-04.5, US-04.6

**ADR(s)** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md) · [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md)

---

### US-04.2 — Permissions `Compute Gallery Image Reader` sur la gallery

**Épopée** : EPIC-04 | **Persona** : P2 Nadia C. | **Priorité** : Must

> En tant que **Responsable Partner Center**, je veux exécuter `make marketplace-gallery-permissions` et vérifier par `az role assignment list` que les Service Principals Microsoft ont accès à `galSMWMarketplace` afin d'éviter l'erreur "image reference not accessible" lors de la soumission.

#### Critères d'acceptation

- [ ] `make marketplace-gallery-permissions` exécute les deux `az role assignment create` :
  - `Microsoft Partner Center Resource Provider` (ID `497d76fa-f477-478a-aa29-49b0dee35030`) → `Compute Gallery Image Reader`
  - `Compute Image Registry` (ID `5947d96b-019a-46ba-ad4b-8ffc6f493b2e`) → `Compute Gallery Image Reader`
- [ ] `az role assignment list --scope /subscriptions/.../providers/Microsoft.Compute/galleries/galSMWMarketplace` confirme les deux assignations.
- [ ] La gallery `galSMWMarketplace` et le compte Partner Center sont dans le même tenant Entra ID (`aba0984a`).
- [ ] La cible Makefile est idempotente : une réexécution lorsque les permissions existent déjà ne génère pas d'erreur.

#### Tâches

- [ ] Ajouter la cible `marketplace-gallery-permissions` dans le Makefile.
- [ ] Ajouter une vérification de tenant ID avant l'attribution des rôles.
- [ ] Documenter les deux IDs de Service Principals dans ADR-800.

#### Dépendances

- Dépend de : US-04.1 (offre créée, gallery `galSMWMarketplace` doit exister)
- Bloque : US-04.3 (plan technique ne peut pas référencer une gallery sans permissions)

**ADR(s)** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)

---

### US-04.3 — Plan technique lié à l'image certifiée

**Épopée** : EPIC-04 | **Persona** : P2 Nadia C. | **Priorité** : Must

> En tant que **Responsable Partner Center**, je veux configurer le plan technique avec la référence de l'image certifiée depuis `galSMWMarketplace` afin de lier l'image buildée et certifiée à l'offre Marketplace.

#### Critères d'acceptation

- [ ] Le plan technique dans Partner Center référence `galSMWMarketplace/smw-knowledge-base/{version certifiée}` (format `{smw_version}.{YYYYMMDD}`).
- [ ] Le plan est en état "Technical configuration completed" dans Partner Center.
- [ ] La taille de VM minimale configurée dans le plan est `Standard_D2s_v3`.
- [ ] Le disque OS est configuré entre 30 et 50 GB dans les propriétés du plan.
- [ ] `arm/mainTemplate.json` et `arm/createUIDefinition.json` sont uploadés dans le plan technique.

#### Tâches

- [ ] Configurer le plan technique dans Partner Center (action manuelle).
- [ ] Uploader `arm/mainTemplate.json` et `arm/createUIDefinition.json`.
- [ ] Documenter les étapes de configuration du plan dans le runbook (US-04.4).

#### Dépendances

- Dépend de : US-04.2 (permissions gallery), US-01.5 (nommage versionné), US-02.1 (ARM templates)
- Bloque : US-04.6, US-06.1

**ADR(s)** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md) · [ADR-200](../adr/200-INFRA-azure-infrastructure-vm-offer.md)

---

### US-04.4 — Runbook de publication pas-à-pas

**Épopée** : EPIC-04 | **Persona** : P2 Nadia C. | **Priorité** : Must

> En tant que **Responsable Partner Center**, je veux disposer d'un runbook de publication étape par étape dans `docs/` afin de soumettre l'offre sans dépendre d'une connaissance informelle, et de former les futurs contributeurs.

#### Critères d'acceptation

- [ ] Le runbook `docs/runbook-publication.md` couvre les étapes dans l'ordre : build + certification → création offre → permissions gallery → plan technique → contenu listing → soumission Preview → validation smoke tests → soumission Live.
- [ ] Chaque étape référence la cible Makefile applicable ou l'action manuelle Partner Center correspondante.
- [ ] Les prérequis (versions canoniques, IDs tenant, permissions Azure) sont listés en section d'en-tête.
- [ ] Le runbook mentionne le rapport de certification (US-03.6) comme prérequis bloquant à la soumission Preview.
- [ ] Le runbook est relu et validé par P1 Thomas et P5 Jérôme avant la première soumission Live.

#### Tâches

- [ ] Créer `docs/runbook-publication.md` avec les sections décrites ci-dessus.
- [ ] Faire relire par Thomas (P1) pour la partie technique et Jérôme (P5) pour la partie Partner Center.

#### Dépendances

- Dépend de : US-04.1 (offre créée), US-04.3 (plan configuré)
- Bloque : US-06.1, US-06.3 (soumissions suivent le runbook)

**ADR(s)** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md) · [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md)

---

### US-04.5 — Plan tarifaire BYOL/Free, GPL-2.0

**Épopée** : EPIC-04 | **Persona** : P5 Jérôme V. — Product Owner Marketplace | **Priorité** : Must

> En tant que **Product Owner Marketplace**, je veux définir le plan tarifaire BYOL/Free, licence GPL-2.0 dans Partner Center afin de respecter la stratégie commerciale ADR-001 et ADR-800.

#### Critères d'acceptation

- [ ] Le plan tarifaire est configuré en "Bring Your Own License" (BYOL) ou "Free" dans Partner Center.
- [ ] Le modèle de facturation Microsoft Infrastructure Only est sélectionné (l'éditeur ne facture pas via Marketplace).
- [ ] La licence GPL-2.0 est référencée dans la section "Legal" de l'offre.
- [ ] La stratégie tarifaire est documentée et versionnée dans ADR-001 et ADR-800.

#### Tâches

- [ ] Configurer le plan tarifaire dans Partner Center (action manuelle).
- [ ] Uploader ou référencer le texte de la licence GPL-2.0 dans la section légale.
- [ ] Documenter la décision dans ADR-001.

#### Dépendances

- Dépend de : US-04.1 (offre créée)
- Bloque : US-06.1 (soumission Preview requiert plan tarifaire configuré)

**ADR(s)** : [ADR-001](../adr/001-META-definition-projet-smw-marketplace.md) · [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)

---

### US-04.6 — Audience Preview restreinte configurée

**Épopée** : EPIC-04 | **Persona** : P2 Nadia C. | **Priorité** : Must

> En tant que **Responsable Partner Center**, je veux configurer une audience Preview restreinte avant publication publique afin de valider l'offre sur un déploiement réel sans exposer prématurément les acheteurs.

#### Critères d'acceptation

- [ ] L'audience Preview contient au moins un tenant ou abonnement Azure de test (ID tenant ou email de souscription).
- [ ] L'audience Preview peut déployer la VM depuis le Portail Azure en Preview (avant publication Live).
- [ ] Au moins un déploiement complet depuis l'audience Preview est validé avant la soumission Live (US-06.2).
- [ ] L'audience Preview est documentée dans le runbook (US-04.4) — les IDs de test ne sont pas commités publiquement.

#### Tâches

- [ ] Configurer l'audience Preview dans Partner Center (action manuelle).
- [ ] Documenter les IDs/emails de l'audience de test dans un fichier privé ou variable d'environnement sécurisée.
- [ ] Référencer la procédure dans le runbook.

#### Dépendances

- Dépend de : US-04.3 (plan technique configuré), US-04.5 (plan tarifaire configuré)
- Bloque : US-06.1 (soumission Preview)

**ADR(s)** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)

---

## EPIC-05 — Contenu listing et assets Marketplace

**Valeur** : Le listing Marketplace est complet, conforme aux exigences Microsoft, et efficace pour convaincre un acheteur potentiel.

---

### US-05.1 — Description longue HTML conforme section 100

**Épopée** : EPIC-05 | **Persona** : P4 Claire B. — Rédactrice Listing Marketplace | **Priorité** : Must

> En tant que **Rédactrice Listing Marketplace**, je veux rédiger la description longue HTML de l'offre en respectant les exigences "Section 100" de Microsoft afin d'éviter un rejet pour non-conformité de contenu.

#### Critères d'acceptation

- [ ] La description longue HTML (max 5 000 caractères) est rédigée et sauvegardée dans `docs/marketplace-assets/description-longue.html`.
- [ ] Le contenu respecte les exigences Section 100 Microsoft : pas de promesses de fonctionnalités non livrées, pas de mention de concurrents, pas d'hyperliens vers des sites tiers non approuvés.
- [ ] La description inclut les sections : "À propos de Semantic MediaWiki", "Fonctionnalités principales", "Configuration requise" (Ubuntu 22.04 LTS, Standard_D2s_v3+), "Premiers pas".
- [ ] P5 Jérôme valide la description avant upload dans Partner Center.
- [ ] La description uploadée dans Partner Center est validée par l'outil de prévisualisation du listing Microsoft.

#### Tâches

- [ ] Rédiger `docs/marketplace-assets/description-longue.html`.
- [ ] Valider avec Jérôme (P5) et référencer ADR-801.
- [ ] Uploader dans Partner Center (action manuelle).

#### Dépendances

- Dépend de : US-04.1 (offre créée dans Partner Center)
- Bloque : US-05.5 (validation PO), US-06.1 (soumission Preview requiert listing complet)

**ADR(s)** : [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md)

---

### US-05.2 — 4 logos PNG aux formats requis

**Épopée** : EPIC-05 | **Persona** : P4 Claire B. | **Priorité** : Must

> En tant que **Rédactrice Listing Marketplace**, je veux produire les 4 formats de logo PNG requis par Microsoft afin de compléter le listing sans rejet pour assets manquants.

#### Critères d'acceptation

- [ ] Les 4 fichiers PNG suivants sont produits et stockés dans `docs/marketplace-assets/logos/` :
  - `logo-small-48x48.png` (48×48 px)
  - `logo-medium-90x90.png` (90×90 px)
  - `logo-large-216x216.png` (216×216 px)
  - `logo-wide-255x115.png` (255×115 px)
- [ ] Chaque logo a un fond non-transparent (blanc ou couleur de marque).
- [ ] Les fichiers sont en PNG 24 bits, taille < 1 MB chacun.
- [ ] Les 4 logos sont uploadés dans Partner Center et validés par l'outil de prévisualisation.

#### Tâches

- [ ] Produire les 4 variantes PNG depuis le logo source vectoriel.
- [ ] Stocker dans `docs/marketplace-assets/logos/`.
- [ ] Uploader dans Partner Center.

#### Dépendances

- Dépend de : US-04.1 (offre créée)
- Bloque : US-05.5 (validation listing complet)

**ADR(s)** : [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md)

---

### US-05.3 — 3 screenshots 1280×720 annotés depuis une VM de test

**Épopée** : EPIC-05 | **Persona** : P4 Claire B. | **Priorité** : Must

> En tant que **Rédactrice Listing Marketplace**, je veux produire 3 captures d'écran annotées (1280×720 px) depuis une VM de test déployée depuis l'image afin d'illustrer le wiki SMW tel que le client le verra.

#### Critères d'acceptation

- [ ] 3 fichiers PNG `screenshot-01.png`, `screenshot-02.png`, `screenshot-03.png` sont produits et stockés dans `docs/marketplace-assets/screenshots/`.
- [ ] Chaque screenshot est pris depuis une VM déployée depuis l'image gallery (pas depuis un environnement de dev non représentatif).
- [ ] Résolution exacte : 1280×720 px, format PNG.
- [ ] Les screenshots illustrent des aspects différents : page d'accueil du wiki, `Special:Version` (montrant MediaWiki 1.43.x + SMW 6.0.1), et une page avec des propriétés SMW.
- [ ] Les 3 screenshots sont uploadés dans Partner Center et validés par l'outil de prévisualisation.

#### Tâches

- [ ] Déployer une VM de test depuis la dernière image gallery certifiée.
- [ ] Produire les 3 screenshots et les stocker dans `docs/marketplace-assets/screenshots/`.
- [ ] Uploader dans Partner Center.

#### Dépendances

- Dépend de : US-02.2 (firstboot opérationnel pour avoir un wiki fonctionnel), US-03.1 (image certifiée)
- Bloque : US-05.5 (validation listing complet)

**ADR(s)** : [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md)

---

### US-05.4 — Guide post-déploiement public

**Épopée** : EPIC-05 | **Persona** : P4 Claire B. | **Priorité** : Must

> En tant que **Rédactrice Listing Marketplace**, je veux rédiger un guide post-déploiement public afin d'accompagner le client Azure dans les 30 premières minutes après le déploiement.

#### Critères d'acceptation

- [ ] Le guide `docs/marketplace-assets/post-deployment-guide.md` couvre : accès HTTPS au wiki, accès SSH, remplacement du certificat TLS self-signed par Let's Encrypt ou un certificat custom, chemin du log `/var/log/smw-firstboot.log`, opérations de base (ajouter un utilisateur, créer une propriété SMW).
- [ ] Le guide est rédigé en anglais (langue requise pour Marketplace) avec une version française optionnelle.
- [ ] Le guide est lié depuis la description longue de l'offre (US-05.1).
- [ ] Le guide est hébergé à une URL stable (dépôt GitHub ou docs publiques) référencée dans Partner Center.

#### Tâches

- [ ] Rédiger `docs/marketplace-assets/post-deployment-guide.md`.
- [ ] Référencer `/var/log/smw-firstboot.log` (US-02.5) dans la section "Troubleshooting".
- [ ] Publier et référencer l'URL stable dans Partner Center.

#### Dépendances

- Dépend de : US-02.5 (log firstboot documenté), US-05.1 (description longue rédigée)
- Bloque : US-05.5 (validation listing complet)

**ADR(s)** : [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md)

---

### US-05.5 — Validation stratégique du listing par le PO

**Épopée** : EPIC-05 | **Persona** : P5 Jérôme V. | **Priorité** : Must

> En tant que **Product Owner Marketplace**, je veux valider l'ensemble du listing (description, logos, screenshots, guide) avant soumission Preview afin de m'assurer de la conformité avec ADR-801 et ADR-001 avant d'engager le cycle de review Microsoft.

#### Critères d'acceptation

- [ ] P5 Jérôme effectue une revue formelle du listing complet (US-05.1 à US-05.4) avant la soumission Preview.
- [ ] La revue vérifie la conformité avec ADR-801 (stratégie documentation) et ADR-001 (définition projet).
- [ ] Toute correction demandée par P5 est appliquée et re-validée avant soumission.
- [ ] La validation est consignée dans le runbook de publication (US-04.4) avec date et signature.

#### Tâches

- [ ] Planifier la session de revue avec P5 Jérôme avant la soumission Preview.
- [ ] Appliquer les corrections identifiées.
- [ ] Consigner la validation dans le runbook.

#### Dépendances

- Dépend de : US-05.1, US-05.2, US-05.3, US-05.4 (tous les assets listing produits)
- Bloque : US-06.1 (soumission Preview)

**ADR(s)** : [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md) · [ADR-001](../adr/001-META-definition-projet-smw-marketplace.md)

---

### US-05.6 — Checklist de mise à jour du listing par release

**Épopée** : EPIC-05 | **Persona** : P5 Jérôme V. | **Priorité** : Should

> En tant que **Product Owner Marketplace**, je veux une checklist des éléments listing à mettre à jour à chaque nouvelle release afin d'éviter un listing incohérent avec la version publiée.

#### Critères d'acceptation

- [ ] La checklist `docs/marketplace-assets/update-checklist.md` liste tous les éléments à vérifier lors d'une mise à jour de version : description longue (numéros de version), screenshots (`Special:Version` mis à jour), plan technique (référence image), guide post-déploiement, ADR-001.
- [ ] La checklist est référencée dans le runbook de publication (US-04.4) dans la section "Mise à jour d'une release".
- [ ] Chaque item de la checklist est accompagné d'un critère de validation ("comment savoir que c'est fait").

#### Tâches

- [ ] Créer `docs/marketplace-assets/update-checklist.md`.
- [ ] Référencer la checklist dans le runbook (US-04.4).

#### Dépendances

- Dépend de : US-05.1 à US-05.4 (assets listing connus)
- Bloque : — (améliore le processus de release, non bloquant pour le Live initial)

**ADR(s)** : [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md)

---

## EPIC-06 — Publication live et go-to-market

**Valeur** : L'offre est publiée en Live sur Azure Marketplace, mesurée et maintenue.

---

### US-06.1 — Soumission Preview et déploiement de validation

**Épopée** : EPIC-06 | **Persona** : P2 Nadia C. | **Priorité** : Must

> En tant que **Responsable Partner Center**, je veux soumettre l'offre en Preview et déployer une VM depuis l'audience Preview afin de valider le déploiement réel avant la publication Live.

#### Critères d'acceptation

- [ ] La soumission Preview est déclenchée dans Partner Center après validation de toutes les étapes EPIC-04 et EPIC-05.
- [ ] La soumission passe la revue automatique Microsoft (24-48h) sans erreur de validation.
- [ ] Une VM est déployée avec succès depuis l'audience Preview via le Portail Azure (pas depuis la gallery directement).
- [ ] Le rapport de certification (US-03.6) est commité dans Git avant la soumission Preview.
- [ ] L'offre atteint l'état "Preview" dans Partner Center.

#### Tâches

- [ ] Soumettre l'offre en Preview dans Partner Center (action manuelle).
- [ ] Déployer une VM de validation depuis le Portail Azure en tant qu'audience Preview.
- [ ] Documenter le résultat dans le runbook.

#### Dépendances

- Dépend de : US-04.6 (audience Preview), US-05.5 (listing validé), US-03.6 (rapport certif), US-04.4 (runbook)
- Bloque : US-06.2, US-06.3

**ADR(s)** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)

---

### US-06.2 — Smoke tests sur la VM Preview déployée

**Épopée** : EPIC-06 | **Persona** : P1 Thomas R. | **Priorité** : Must

> En tant que **DevOps Image Builder**, je veux exécuter les smoke tests fonctionnels sur la VM déployée depuis l'audience Preview afin de confirmer que le déploiement Marketplace se comporte identiquement au déploiement gallery direct.

#### Critères d'acceptation

- [ ] Les smoke tests vérifient : `https://{wikiHostName}/` retourne HTTP 200, `Special:Version` affiche MediaWiki 1.43.x et SMW 6.0.1, MySQL écoute uniquement sur `127.0.0.1:3306`, SSH n'accepte que la clé publique configurée au déploiement.
- [ ] Les smoke tests sont exécutés via `make vm-test VM_HOST={ip_preview}` sur la VM Preview déployée.
- [ ] Tous les contrôles doivent être `[PASS]` avant soumission Live.
- [ ] Le résultat des smoke tests est documenté dans le runbook (US-04.4).

#### Tâches

- [ ] Exécuter `make vm-test` sur la VM Preview avec les paramètres du déploiement Marketplace.
- [ ] Documenter les résultats et résoudre les éventuels écarts.

#### Dépendances

- Dépend de : US-06.1 (VM Preview déployée), US-03.1 (make vm-test opérationnel)
- Bloque : US-06.3 (smoke tests doivent passer avant soumission Live)

**ADR(s)** : [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) · [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)

---

### US-06.3 — Soumission Live

**Épopée** : EPIC-06 | **Persona** : P2 Nadia C. | **Priorité** : Must

> En tant que **Responsable Partner Center**, je veux déclencher la soumission Live après validation des smoke tests Preview afin de rendre l'offre publiquement disponible sur Azure Marketplace.

#### Critères d'acceptation

- [ ] La soumission Live est déclenchée uniquement après validation des smoke tests Preview (US-06.2) — toutes `[PASS]`.
- [ ] La soumission passe la revue Microsoft (jusqu'à 7 jours ouvrés) et atteint l'état "Live".
- [ ] L'offre est visible publiquement sur `azuremarketplace.microsoft.com` avec le listing complet (description, logos, screenshots).
- [ ] La date de publication Live est enregistrée dans le runbook et dans ADR-800.

#### Tâches

- [ ] Déclencher la soumission Live dans Partner Center (action manuelle, après validation US-06.2).
- [ ] Suivre l'état de la review Microsoft.
- [ ] Documenter la date de publication Live dans le runbook et ADR-800.

#### Dépendances

- Dépend de : US-06.2 (smoke tests Preview OK)
- Bloque : US-06.4, US-06.5

**ADR(s)** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)

---

### US-06.4 — Dashboard Partner Center partagé avec l'équipe

**Épopée** : EPIC-06 | **Persona** : P5 Jérôme V. | **Priorité** : Should

> En tant que **Product Owner Marketplace**, je veux un accès partagé au dashboard Partner Center afin de suivre les métriques de déploiement (leads, vues, déploiements) sans dépendre de Nadia.

#### Critères d'acceptation

- [ ] P5 Jérôme et P4 Claire ont un accès "Viewer" (en lecture seule) au dashboard Partner Center de l'offre `smw-knowledge-base`.
- [ ] Le dashboard affiche les métriques : nombre de déploiements, leads capturés, page views du listing.
- [ ] L'accès est configuré via "User Management" dans Partner Center (pas de partage de credentials).

#### Tâches

- [ ] Configurer les accès "User Management" dans Partner Center pour P5 et P4.
- [ ] Documenter la procédure d'accès dans le runbook.

#### Dépendances

- Dépend de : US-06.3 (offre Live, dashboard actif)
- Bloque : — (améliore la visibilité, non bloquant)

**ADR(s)** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)

---

### US-06.5 — URLs de campagne ocid/utm_* pour le go-to-market

**Épopée** : EPIC-06 | **Persona** : P5 Jérôme V. | **Priorité** : Should

> En tant que **Product Owner Marketplace**, je veux des URLs de campagne avec paramètres `ocid` et `utm_*` afin de mesurer l'efficacité des canaux de promotion (blog, réseaux sociaux, email).

#### Critères d'acceptation

- [ ] Au moins 3 URLs de campagne sont générées pour l'offre Live, avec `ocid` (Azure attribution) et `utm_source`, `utm_medium`, `utm_campaign`.
- [ ] Les URLs ciblent la page listing de l'offre sur `azuremarketplace.microsoft.com`.
- [ ] Les URLs sont documentées dans `docs/marketplace-assets/campaign-urls.md` avec description de chaque canal.
- [ ] Les UTM sont configurés pour être traçables dans les analytics (partenariat Google Analytics ou équivalent si disponible).

#### Tâches

- [ ] Générer les URLs depuis le Partner Center ou manuellement avec les paramètres UTM.
- [ ] Créer `docs/marketplace-assets/campaign-urls.md`.

#### Dépendances

- Dépend de : US-06.3 (offre Live, URL listing connue)
- Bloque : — (go-to-market, non bloquant)

**ADR(s)** : [ADR-801](../adr/801-BIZ-strategie-documentation-marketplace.md)

---

### US-06.6 — Runbook de gestion des rejets Microsoft

**Épopée** : EPIC-06 | **Persona** : P2 Nadia C. | **Priorité** : Must

> En tant que **Responsable Partner Center**, je veux un runbook de gestion des rejets Microsoft afin de reprendre le cycle de soumission rapidement sans improviser la remédiation.

#### Critères d'acceptation

- [ ] Le runbook `docs/runbook-rejection.md` couvre les scénarios de rejet connus : AMAT non-conforme, image non accessible (permissions gallery), assets listing non conformes, ARM template invalide, violation Section 100.
- [ ] Chaque scénario indique : cause probable, étapes de diagnostic, remédiation (cible Makefile ou action Partner Center), délai estimé.
- [ ] Le runbook est référencé depuis le runbook principal (US-04.4) dans la section "En cas de rejet".
- [ ] Après remédiation, le runbook indique explicitement les étapes de re-soumission.

#### Tâches

- [ ] Créer `docs/runbook-rejection.md` avec les scénarios de rejet listés ci-dessus.
- [ ] Référencer le runbook depuis `docs/runbook-publication.md`.

#### Dépendances

- Dépend de : US-04.4 (runbook publication), US-03.5 (traçabilité AMAT)
- Bloque : — (prépare la résilience du cycle, non bloquant pour Live initial)

**ADR(s)** : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)

---

## Matrice de priorités

| Priorité | Nombre de US | IDs |
|----------|-------------|-----|
| Must | 30 | Toutes sauf US-01.— (Must), US-02.5, US-02.6, US-03.5, US-04.—, US-05.6, US-06.4, US-06.5 |
| Should | 6 | US-02.5, US-02.6, US-03.5, US-05.6, US-06.4, US-06.5 |
| Could | 0 | — |

> **Principe "nécessaire et suffisant"** : Les 30 US Must sont le chemin critique vers la publication Live. Les 6 US Should améliorent la robustesse opérationnelle et le go-to-market sans bloquer la DoD des épopées.
