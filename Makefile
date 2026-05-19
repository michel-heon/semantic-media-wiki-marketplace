# =============================================================================
# Semantic MediaWiki Marketplace — Makefile principal
# =============================================================================
# ┌──────────────────────────────────────────────────────────────────────────┐
# │  RÈGLES ARCHITECTURALES — OBLIGATOIRES POUR TOUTE MODIFICATION (IA/DEV)│
# ├──────────────────────────────────────────────────────────────────────────┤
# │  ADR-600 · Configuration                                                 │
# │    · Sources : env/.env.dev (public) + env/.env.dev.user (secrets)      │
# │    · env/generated/ est AUTO-GÉNÉRÉ par 'make config' → NE PAS ÉDITER  │
# │    · Workflow : éditer la source → make config → make image-build        │
# │                                                                          │
# │  ADR-601 · Nomenclature scripts                                          │
# │    · Format : {objet}-{action}.sh  (ex: vm-manage.sh, check-env.sh)     │
# │    · Emplacement : packer/scripts/  — tout en minuscules, tirets        │
# │                                                                          │
# │  ADR-602 · Makefile = ORCHESTRATEUR UNIQUEMENT                          │
# │    · Règle des 3 lignes : logique >3 lignes → packer/scripts/*.sh       │
# │    · Pattern target = $(call log_action) + [guard] + @bash script.sh    │
# │    · JAMAIS de boucles, conditions complexes ou transformations inline  │
# │                                                                          │
# │  ADR-611 · Couleurs et affichage                                         │
# │    · @printf UNIQUEMENT — JAMAIS @echo ni @echo -e                      │
# │    · Macros : $(call log_action,…)  $(call log_success,…)               │
# │               $(call log_warning,…) $(call log_error,…)                 │
# │               $(call log_info,…)                                         │
# └──────────────────────────────────────────────────────────────────────────┘
#
# Usage: make help

# ---------------------------------------------------------------------------
# Couleurs (ADR-611 — utiliser @printf, jamais @echo -e)
# ---------------------------------------------------------------------------
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
CYAN   := \033[0;36m
BOLD   := \033[1m
NC     := \033[0m

# ---------------------------------------------------------------------------
# Macros de log (ADR-611 — utiliser $(call log_*,message) dans les targets)
# ---------------------------------------------------------------------------
define log_action
	@printf "$(CYAN)➤ $(1)$(NC)\n"
endef

define log_success
	@printf "$(GREEN)✓ $(1)$(NC)\n"
endef

define log_warning
	@printf "$(YELLOW)⚠ $(1)$(NC)\n"
endef

define log_error
	@printf "$(RED)✗ $(1)$(NC)\n"
endef

define log_info
	@printf "$(BLUE)ℹ $(1)$(NC)\n"
endef

# ---------------------------------------------------------------------------
# Variables calculées
# ---------------------------------------------------------------------------
BUILD_DATE := $(shell date +%Y%m%d)
PACKER_DIR := packer
ENV_DEV    := env/.env.dev
ENV_USER   := env/.env.dev.user
PKRVARS    := packer/generated.pkrvars.hcl

# Inclusion de la configuration générée (produite par 'make config')
-include env/generated/config.make

.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Aide automatique (ADR-602)
# Convention : ##@ pour les sections, ## pour les cibles
# ---------------------------------------------------------------------------
.PHONY: help
help: ## Afficher l'aide
	@printf "$(BOLD)$(CYAN)Semantic MediaWiki Marketplace$(NC)\n"
	@printf "$(CYAN)══════════════════════════════════════════════$(NC)\n"
	@awk 'BEGIN {FS = ":.*##"; printf ""} \
	    /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2 } \
	    /^##@/ { printf "\n$(BOLD)$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@printf "\n$(CYAN)BUILD_DATE=$(NC)$(BUILD_DATE)\n"

##@ Configuration

.PHONY: setup
setup: ## Installer les prérequis (packer, az cli)
	$(call log_action,Vérification des prérequis...)
	@command -v packer >/dev/null 2>&1 || { printf "$(RED)ERREUR: packer non installé. Voir https://developer.hashicorp.com/packer/install$(NC)\n"; exit 1; }
	@command -v az >/dev/null 2>&1 || { printf "$(RED)ERREUR: az cli non installé. Voir https://learn.microsoft.com/cli/azure/install-azure-cli$(NC)\n"; exit 1; }
	@command -v wget >/dev/null 2>&1 || { printf "$(RED)ERREUR: wget non installé$(NC)\n"; exit 1; }
	$(call log_success,Prérequis OK)

.PHONY: azure-credential
azure-credential: ## Login Azure et injecter les credentials SP dans env/.env.dev.user
	$(call log_action,Connexion Azure et injection des credentials...)
	@bash packer/scripts/azure-credential.sh
	$(call log_success,Credentials prêts — lancez : make config && make image-build)

.PHONY: check-env
check-env: ## Vérifier les variables d'environnement requises avant build
	$(call log_action,Vérification des variables d'environnement...)
	@bash packer/scripts/check-env.sh
	$(call log_success,Variables d'environnement OK)

.PHONY: config
config: ## Générer env/generated/config.make depuis les fichiers .env (ADR-600)
	$(call log_action,Génération de la configuration...)
	@bash packer/scripts/config-generate.sh
	$(call log_success,Configuration générée dans env/generated/)

##@ Packer — Build Image

.PHONY: packer-init
packer-init: ## Initialiser les plugins Packer (téléchargement hashicorp/azure)
	$(call log_action,Initialisation des plugins Packer...)
	packer init "$(PACKER_DIR)/"
	$(call log_success,Plugins Packer initialisés)

.PHONY: image-validate
image-validate: check-env ## Valider le template Packer sans construire
	$(call log_action,Validation du template Packer...)
	packer validate \
	    -var-file="$(PKRVARS)" \
	    -var "build_date=$(BUILD_DATE)" \
	    "$(PACKER_DIR)/"
	$(call log_success,Template Packer valide)

.PHONY: image-build
image-build: check-env ## Construire l'image SMW (lance packer build)
	$(call log_action,Construction de l'image VM SMW — BUILD_DATE=$(BUILD_DATE))
	packer init "$(PACKER_DIR)/" && packer build \
	    -var-file="$(PKRVARS)" \
	    -var "build_date=$(BUILD_DATE)" \
	    "$(PACKER_DIR)/"
	$(call log_success,Image VM construite avec succès)

.PHONY: image-build-force
image-build-force: check-env ## Reconstruire l'image SMW (force — écrase les artefacts existants)
	$(call log_action,Construction forcée de l'image VM SMW — BUILD_DATE=$(BUILD_DATE))
	packer init "$(PACKER_DIR)/" && packer build \
	    -force \
	    -var-file="$(PKRVARS)" \
	    -var "build_date=$(BUILD_DATE)" \
	    "$(PACKER_DIR)/"
	$(call log_success,Image VM reconstruite avec succès)

##@ Blob Storage — Cache de packages

.PHONY: storage-create
storage-create: ## Créer le compte de stockage et le conteneur blob
	$(call log_action,Création du Blob Storage...)
	@bash packer/scripts/storage-provision.sh create
	$(call log_success,Blob Storage prêt)

.PHONY: storage-upload
storage-upload: ## Uploader les packages vers le cache blob
	$(call log_action,Upload des packages vers le blob...)
	@bash packer/scripts/storage-provision.sh upload
	$(call log_success,Packages uploadés)

.PHONY: storage-verify
storage-verify: ## Vérifier la présence des packages dans le blob
	$(call log_action,Vérification du blob storage...)
	@bash packer/scripts/storage-provision.sh verify
	$(call log_success,Vérification terminée)

.PHONY: storage-list
storage-list: ## Lister les packages dans le blob
	@bash packer/scripts/storage-provision.sh list

.PHONY: storage-urls
storage-urls: ## Afficher les URLs des packages dans le blob
	@bash packer/scripts/storage-provision.sh urls

##@ Marketplace — Validation Azure (ADR-800)

# VM de test E2E (peut être surchargé : make vm-ensure E2E_RG=autre-rg)
E2E_RG ?= rg-smw-marketplace-e2e
CTT     := packer/scripts/marketplace-ctt.sh

.PHONY: vm-ensure vm-stop vm-start vm-delete vm-status image-id
.PHONY: vm-dns-assign vm-dns-assign-reboot vm-firstboot-reset vm-reset-admin
.PHONY: marketplace-info marketplace-validate marketplace-all marketplace-test marketplace-tests

vm-ensure: ## Créer la VM de test SMW si elle n'existe pas (depuis dernière image gallery)
	$(call log_action,Vérification / création VM de test...)
	@BUILD_DATE=$(BUILD_DATE) E2E_RG=$(E2E_RG) bash packer/scripts/vm-manage.sh ensure

vm-stop: ## Deallocater la VM de test SMW
	$(call log_action,Arrêt de la VM de test...)
	@E2E_RG=$(E2E_RG) bash packer/scripts/vm-manage.sh stop

vm-start: ## Démarrer la VM de test SMW
	$(call log_action,Démarrage de la VM de test...)
	@E2E_RG=$(E2E_RG) bash packer/scripts/vm-manage.sh start

vm-delete: ## Supprimer la VM de test SMW
	$(call log_action,Suppression de la VM de test...)
	@E2E_RG=$(E2E_RG) bash packer/scripts/vm-manage.sh delete

vm-status: ## Afficher l'état, l'IP, le DNS et l'URL de la VM de test
	$(call log_action,Statut de la VM de test...)
	@E2E_RG=$(E2E_RG) bash packer/scripts/vm-manage.sh status

image-id: ## Afficher l'ID et la version de la dernière image gallery
	$(call log_action,Récupération de l'ID image gallery...)
	@bash packer/scripts/vm-manage.sh id

vm-dns-assign: ## Assigner un label DNS à l'IP publique de la VM de test
	$(call log_action,Attribution d'un label DNS à la VM de test...)
	@E2E_RG=$(E2E_RG) bash packer/scripts/vm-manage.sh dns-assign

vm-dns-assign-reboot: ## Assigner le DNS puis rebooter la VM (auto-config via IMDS au démarrage)
	$(call log_action,Attribution DNS + redémarrage de la VM de test...)
	@E2E_RG=$(E2E_RG) bash packer/scripts/vm-manage.sh dns-assign-reboot

vm-firstboot-reset: ## Effacer le sentinel + relancer smw-firstboot avec le FQDN courant
	$(call log_action,Réinitialisation de smw-firstboot sur la VM de test...)
	@E2E_RG=$(E2E_RG) bash packer/scripts/vm-manage.sh firstboot-reset

vm-reset-admin: ## Réinitialiser le mot de passe WikiAdmin à ChangeMe123! (maintenance/changePassword.php)
	$(call log_action,Réinitialisation du mot de passe WikiAdmin...)
	@E2E_RG=$(E2E_RG) bash packer/scripts/vm-manage.sh reset-admin-password

marketplace-info: ## Afficher les infos sur la validation Marketplace CTT
	@bash $(CTT) info

marketplace-validate: vm-ensure ## Valider conformité Azure Marketplace sur VM de test
	@bash $(CTT) validate $(VM)

marketplace-all: vm-ensure ## Exécuter tous les tests CTT (alias validate)
	@bash $(CTT) all $(VM)

marketplace-test: ## Exécuter un test CTT spécifique (TEST=nom VM=vm_name)
	@bash $(CTT) test $(TEST) $(VM)

marketplace-tests: ## Lister les tests CTT disponibles
	@bash $(CTT) list

.PHONY: marketplace-gallery-permissions
marketplace-gallery-permissions: ## Configurer les permissions ACG pour Partner Center (ADR-800 Décision 1)
	$(call log_action,Configuration des permissions Azure Compute Gallery pour Partner Center...)
	@GALLERY_NAME=$(GALLERY_NAME) \
	    GALLERY_RESOURCE_GROUP=$(GALLERY_RESOURCE_GROUP) \
	    bash packer/scripts/marketplace-gallery-permissions.sh
	$(call log_success,Permissions gallery configurées — Partner Center peut accéder à la gallery)

.PHONY: marketplace-gallery-recreate
marketplace-gallery-recreate: ## Recréer l'image definition avec publisher=GALLERY_IMAGE_PUBLISHER (fix dropdown Partner Center)
	$(call log_action,Recréation de l'image definition $(GALLERY_IMAGE_NAME) avec publisher=$(GALLERY_IMAGE_PUBLISHER)...)
	@GALLERY_NAME=$(GALLERY_NAME) \
	    GALLERY_RESOURCE_GROUP=$(GALLERY_RESOURCE_GROUP) \
	    GALLERY_IMAGE_NAME=$(GALLERY_IMAGE_NAME) \
	    GALLERY_IMAGE_PUBLISHER=$(GALLERY_IMAGE_PUBLISHER) \
	    AZURE_SUBSCRIPTION_ID=$(AZURE_SUBSCRIPTION_ID) \
	    AZURE_LOCATION=$(AZURE_LOCATION) \
	    SMW_VERSION=$(SMW_VERSION) \
	    bash packer/scripts/marketplace-gallery-recreate.sh
	$(MAKE) marketplace-gallery-permissions
	$(call log_success,Image definition recréée — vérifier le dropdown $(GALLERY_NAME) / $(GALLERY_IMAGE_NAME) dans Partner Center)

##@ Tests Frontend

.PHONY: frontend-test-login-ui

frontend-test-login-ui: ## Exécuter les tests UI de la page login MediaWiki (curl + validation)
	$(call log_action,Test UI de la page de login SMW...)
	@E2E_RG=$(E2E_RG) bash packer/scripts/frontend-test.sh login-ui

##@ ARM — Validation (US-02.1)

.PHONY: arm-validate
arm-validate: ## Valider la syntaxe du template ARM mainTemplate.json (az deployment validate)
	$(call log_action,Validation ARM template mainTemplate.json...)
	@az deployment group validate \
		--resource-group "$(E2E_RG)" \
		--template-file arm/mainTemplate.json \
		--parameters imageId="/subscriptions/dummy/resourceGroups/dummy/providers/Microsoft.Compute/galleries/dummy/images/dummy/versions/1.0.0" adminUsername="testuser" adminPublicKey="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0" wikiHostName="wiki.example.com" wikiAdminEmail="admin@example.com" wikiAdminPassword="T3stPassword1!" databasePassword="T3stPassword2!" \
		--output table 2>&1 | grep -E "^(Deployment|ERROR|error|Result|State)" || true
	$(call log_success,Template ARM valide)

##@ Dev Workflow — Itération VM (ADR-614)

.PHONY: vm-dev-create
vm-dev-create: ## Créer une VM de développement depuis la dernière image gallery (DEV_RG=rg-smw-dev-<user>)
	$(call log_action,Création VM dev depuis la dernière image gallery...)
	@bash packer/scripts/vm-dev-manage.sh create
	$(call log_success,VM dev créée — utilisez 'make vm-dev-status' pour l'IP SSH)

.PHONY: provision-push
provision-push: ## Synchroniser les scripts provisioners sur la VM dev sans rebuild Packer (ADR-614)
	$(call log_action,Synchronisation des provisioners vers la VM dev...)
	@bash packer/scripts/vm-dev-manage.sh push
	$(call log_success,Provisioners synchronisés)

.PHONY: vm-dev-delete
vm-dev-delete: ## Supprimer la VM dev et son resource group dédié
	$(call log_warning,Suppression de la VM dev et son resource group...)
	@bash packer/scripts/vm-dev-manage.sh delete
	$(call log_success,Suppression lancée — opération asynchrone Azure)

.PHONY: vm-dev-status
vm-dev-status: ## Afficher l'état, l'IP et la commande SSH de la VM dev
	$(call log_action,Statut de la VM dev...)
	@bash packer/scripts/vm-dev-manage.sh status

##@ Tests d'Intégration (ADR-700)

.PHONY: integration-test-static
integration-test-static: ## Phase 1 — Tests statiques : HCL2, ARM JSON, scan secrets, permissions (aucun accès Azure)
	@$(MAKE) -C tests/integration static --no-print-directory

.PHONY: integration-test-image
integration-test-image: ## Phase 2 — Tests image gallery via SSH (E2E_RG et VM_NAME requis)
	@$(MAKE) -C tests/integration image --no-print-directory

.PHONY: integration-test-e2e
integration-test-e2e: ## Phase 3 — Tests E2E post-déploiement ARM (firstboot déclenché)
	@$(MAKE) -C tests/integration e2e --no-print-directory

.PHONY: integration-test
integration-test: ## Suite complète : Phase 1 (static) + Phase 2 (image) + Phase 3 (e2e)
	@$(MAKE) -C tests/integration all --no-print-directory

##@ Tests Navigateur (Playwright)

.PHONY: e2e-browser-install
e2e-browser-install: ## Installer les dépendances npm + navigateur Firefox (Playwright)
	@$(MAKE) -C tests install --no-print-directory

.PHONY: e2e-browser
e2e-browser: ## Tests navigateur Firefox — page principale SMW (VM_IP auto depuis Azure)
	@$(MAKE) -C tests/e2e firefox $(if $(VM_IP),VM_IP=$(VM_IP)) --no-print-directory

.PHONY: user-smoke
user-smoke: ## Smoke tests utilisateur SMW — Special:Ask, Browse, annotations, API (VM_IP auto depuis Azure)
	@$(MAKE) -C tests/user-smoke smoke $(if $(VM_IP),VM_IP=$(VM_IP)) --no-print-directory

##@ Maintenance

.PHONY: clean
clean: ## Supprimer les fichiers générés (env/generated/, packer/generated.pkrvars.hcl)
	$(call log_warning,Nettoyage des fichiers générés...)
	@rm -rf env/generated/
	@rm -f packer/generated.pkrvars.hcl
	$(call log_success,Nettoyage terminé)
