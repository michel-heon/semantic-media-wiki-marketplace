# =============================================================================
# Semantic MediaWiki Marketplace — Makefile principal
# =============================================================================
# ┌──────────────────────────────────────────────────────────────────────────┐
# │  RÈGLES ARCHITECTURALES — OBLIGATOIRES POUR TOUTE MODIFICATION (IA/DEV)│
# ├──────────────────────────────────────────────────────────────────────────┤
# │  ADR-600 · Configuration                                                 │
# │    · Sources : env/.env.dev (public) + env/.env.dev.user (secrets)      │
# │    · env/generated/ est AUTO-GÉNÉRÉ par 'make config' → NE PAS ÉDITER  │
# │    · Workflow : éditer la source → make config → make vm-build          │
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
	$(call log_success,Credentials prêts — lancez : make config && make vm-build)

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

##@ Packer — Build VM

.PHONY: packer-init
packer-init: ## Initialiser les plugins Packer (téléchargement hashicorp/azure)
	$(call log_action,Initialisation des plugins Packer...)
	packer init "$(PACKER_DIR)/"
	$(call log_success,Plugins Packer initialisés)

.PHONY: vm-validate
vm-validate: check-env ## Valider le template Packer sans construire
	$(call log_action,Validation du template Packer...)
	packer validate \
	    -var-file="$(PKRVARS)" \
	    -var "build_date=$(BUILD_DATE)" \
	    "$(PACKER_DIR)/"
	$(call log_success,Template Packer valide)

.PHONY: vm-build
vm-build: check-env ## Construire l'image VM SMW (lance packer build)
	$(call log_action,Construction de l'image VM SMW — BUILD_DATE=$(BUILD_DATE))
	packer init "$(PACKER_DIR)/" && packer build \
	    -var-file="$(PKRVARS)" \
	    -var "build_date=$(BUILD_DATE)" \
	    "$(PACKER_DIR)/"
	$(call log_success,Image VM construite avec succès)

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
.PHONY: vm-dns-assign vm-dns-assign-reboot
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

##@ Tests Frontend

.PHONY: frontend-test-login-ui

frontend-test-login-ui: ## Exécuter les tests UI de la page login MediaWiki (curl + validation)
	$(call log_action,Test UI de la page de login SMW...)
	@E2E_RG=$(E2E_RG) bash packer/scripts/frontend-test.sh login-ui

##@ Maintenance

.PHONY: clean
clean: ## Supprimer les fichiers générés (env/generated/, packer/generated.pkrvars.hcl)
	$(call log_warning,Nettoyage des fichiers générés...)
	@rm -rf env/generated/
	@rm -f packer/generated.pkrvars.hcl
	$(call log_success,Nettoyage terminé)
