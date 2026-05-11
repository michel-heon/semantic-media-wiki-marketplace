# Semantic MediaWiki Marketplace — Makefile principal
# ADR-602 — Makefile comme orchestrateur
# ADR-611 — Gestion des couleurs dans les scripts Make
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
	@printf "$(CYAN)>> Vérification des prérequis...$(NC)\n"
	@command -v packer >/dev/null 2>&1 || { printf "$(RED)ERREUR: packer non installé. Voir https://developer.hashicorp.com/packer/install$(NC)\n"; exit 1; }
	@command -v az >/dev/null 2>&1 || { printf "$(RED)ERREUR: az cli non installé. Voir https://learn.microsoft.com/cli/azure/install-azure-cli$(NC)\n"; exit 1; }
	@command -v wget >/dev/null 2>&1 || { printf "$(RED)ERREUR: wget non installé$(NC)\n"; exit 1; }
	@printf "$(GREEN)>> Prérequis OK$(NC)\n"

.PHONY: azure-credential
azure-credential: ## Login Azure via navigateur et injecter les credentials dans env/.env.dev.user
	@printf "$(BOLD)$(CYAN)>> Connexion Azure via navigateur...$(NC)\n"
	@command -v az >/dev/null 2>&1 || { printf "$(RED)ERREUR: az cli non installé. Voir https://learn.microsoft.com/cli/azure/install-azure-cli$(NC)\n"; exit 1; }
	@az login --output none
	@printf "$(CYAN)>> Extraction de la souscription active...$(NC)\n"
	@SUBSCRIPTION_ID=$$(az account show --query id -o tsv 2>/dev/null); \
	TENANT_ID=$$(az account show --query tenantId -o tsv 2>/dev/null); \
	if [ -z "$$SUBSCRIPTION_ID" ]; then \
	    printf "$(RED)>> Impossible d'obtenir la souscription. Vérifiez le login Azure.$(NC)\n"; exit 1; \
	fi; \
	printf "$(CYAN)>> Souscription : $${SUBSCRIPTION_ID}$(NC)\n"; \
	printf "$(CYAN)>> Tenant       : $${TENANT_ID}$(NC)\n"; \
	SP_TMPFILE=$$(mktemp /tmp/sp-smw-XXXXXX.json); \
	EXISTING_SP=$$(az ad sp list --display-name "sp-smw-packer" --query "[0].appId" -o tsv 2>/dev/null); \
	if [ -n "$$EXISTING_SP" ] && [ "$$EXISTING_SP" != "None" ]; then \
	    printf "$(YELLOW)>> SP 'sp-smw-packer' existant détecté — régénération des credentials...$(NC)\n"; \
	    az ad sp credential reset --id "$$EXISTING_SP" --only-show-errors --output json > "$$SP_TMPFILE" 2>/dev/null; \
	else \
	    printf "$(CYAN)>> Création du Service Principal 'sp-smw-packer'...$(NC)\n"; \
	    az ad sp create-for-rbac \
	        --name "sp-smw-packer" \
	        --role "Contributor" \
	        --scopes "/subscriptions/$${SUBSCRIPTION_ID}" \
	        --only-show-errors \
	        --output json > "$$SP_TMPFILE" 2>/dev/null; \
	fi; \
	if ! grep -q '"appId"' "$$SP_TMPFILE" 2>/dev/null; then \
	    printf "$(RED)>> Erreur SP — contenu reçu :$(NC)\n"; cat "$$SP_TMPFILE"; \
	    rm -f "$$SP_TMPFILE"; exit 1; \
	fi; \
	CLIENT_ID=$$(python3 -c "import json; d=json.load(open('$$SP_TMPFILE')); print(d['appId'])"); \
	CLIENT_SECRET=$$(python3 -c "import json; d=json.load(open('$$SP_TMPFILE')); print(d['password'])"); \
	rm -f "$$SP_TMPFILE"; \
	printf "$(GREEN)  CLIENT_ID     : $${CLIENT_ID}$(NC)\n"; \
	awk -v sid="$$SUBSCRIPTION_ID" -v ten="$$TENANT_ID" \
	    -v cli="$$CLIENT_ID" -v sec="$$CLIENT_SECRET" \
	    '/^AZURE_SUBSCRIPTION_ID=/ { print "AZURE_SUBSCRIPTION_ID=\"" sid "\""; next } \
	     /^AZURE_TENANT_ID=/        { print "AZURE_TENANT_ID=\"" ten "\""; next } \
	     /^AZURE_CLIENT_ID=/        { print "AZURE_CLIENT_ID=\"" cli "\""; next } \
	     /^AZURE_CLIENT_SECRET=/    { print "AZURE_CLIENT_SECRET=\"" sec "\""; next } \
	     { print }' env/.env.dev.user.example > "$(ENV_USER)"; \
	printf "$(GREEN)>> Credentials injectés dans $(ENV_USER)$(NC)\n"; \
	printf "$(GREEN)>> Lancez maintenant : make config && make vm-build$(NC)\n"

.PHONY: check-env
check-env: ## Vérifier les variables d'environnement requises avant build
	@printf "$(CYAN)>> Vérification des variables d'environnement...$(NC)\n"
	@set -a; \
	[ -f "$(ENV_DEV)" ] && . "$(ENV_DEV)"; \
	[ -f "$(ENV_USER)" ] && . "$(ENV_USER)"; \
	set +a; \
	missing=0; \
	for var in AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET; do \
	    val=$$(printenv "$$var" 2>/dev/null); \
	    if [ -z "$$val" ] || [ "$$val" = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" ]; then \
	        printf "$(RED)  MANQUANT: $${var}$(NC)\n"; \
	        missing=$$((missing+1)); \
	    else \
	        printf "$(GREEN)  OK: $${var}$(NC)\n"; \
	    fi; \
	done; \
	if [ "$$missing" -gt 0 ]; then \
	    printf "$(RED)>> $${missing} variable(s) manquante(s). Remplir env/.env.dev.user$(NC)\n"; \
	    exit 1; \
	fi
	@printf "$(GREEN)>> Variables d'environnement OK$(NC)\n"

.PHONY: config
config: ## Générer env/generated/config.make depuis les fichiers .env
	@printf "$(CYAN)>> Génération de env/generated/config.make...$(NC)\n"
	@mkdir -p env/generated
	@printf "# Fichier généré automatiquement par 'make config' — NE PAS ÉDITER\n" > env/generated/config.make
	@printf "# Généré le: %s\n" "$$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> env/generated/config.make
	@if [ -f "$(ENV_DEV)" ]; then \
	    grep -v '^#' "$(ENV_DEV)" | grep '=' | \
	    sed 's/=\(.*\)/=\1/' >> env/generated/config.make; \
	fi
	@if [ -f "$(ENV_USER)" ]; then \
	    grep -v '^#' "$(ENV_USER)" | grep '=' | \
	    sed 's/=\(.*\)/=\1/' >> env/generated/config.make; \
	fi
	@printf "$(CYAN)>> Génération de packer/generated.pkrvars.hcl...$(NC)\n"
	@mkdir -p packer
	@printf "# Fichier généré automatiquement par 'make config' — NE PAS ÉDITER\n" > "$(PKRVARS)"
	@[ -f "$(ENV_DEV)" ] && \
	    grep -v '^#' "$(ENV_DEV)" | grep '=' | \
	    sed 's/\([A-Z_]*\)=\(.*\)/\L\1\E = \2/' >> "$(PKRVARS)" || true
	@[ -f "$(ENV_USER)" ] && \
	    grep -v '^#' "$(ENV_USER)" | grep '=' | \
	    sed 's/\([A-Z_]*\)=\(.*\)/\L\1\E = \2/' >> "$(PKRVARS)" || true
	@printf "$(GREEN)>> Configuration générée$(NC)\n"

##@ Packer — Build VM

.PHONY: packer-init
packer-init: ## Initialiser les plugins Packer (téléchargement hashicorp/azure)
	@printf "$(CYAN)>> Initialisation des plugins Packer...$(NC)\n"
	packer init "$(PACKER_DIR)/"
	@printf "$(GREEN)>> Plugins Packer initialisés$(NC)\n"

.PHONY: vm-validate
vm-validate: check-env ## Valider le template Packer sans construire
	@printf "$(CYAN)>> Validation du template Packer...$(NC)\n"
	packer validate \
	    -var-file="$(PKRVARS)" \
	    -var "build_date=$(BUILD_DATE)" \
	    "$(PACKER_DIR)/"
	@printf "$(GREEN)>> Template Packer valide$(NC)\n"

.PHONY: vm-build
vm-build: check-env ## Construire l'image VM SMW (lance packer build)
	@printf "$(BOLD)$(CYAN)>> Construction de l'image VM SMW — BUILD_DATE=$(BUILD_DATE)$(NC)\n"
	packer init "$(PACKER_DIR)/" && \
	packer build \
	    -var-file="$(PKRVARS)" \
	    -var "build_date=$(BUILD_DATE)" \
	    "$(PACKER_DIR)/"
	@printf "$(GREEN)>> Image VM construite avec succès$(NC)\n"

##@ Blob Storage — Cache de packages

.PHONY: storage-create
storage-create: ## Créer le compte de stockage et le conteneur blob
	@printf "$(CYAN)>> Création du Blob Storage...$(NC)\n"
	@bash packer/scripts/storage-provision.sh create
	@printf "$(GREEN)>> Blob Storage créé$(NC)\n"

.PHONY: storage-upload
storage-upload: ## Uploader les packages vers le cache blob
	@printf "$(CYAN)>> Upload des packages vers le blob...$(NC)\n"
	@bash packer/scripts/storage-provision.sh upload
	@printf "$(GREEN)>> Packages uploadés$(NC)\n"

.PHONY: storage-verify
storage-verify: ## Vérifier la présence des packages dans le blob
	@printf "$(CYAN)>> Vérification du blob storage...$(NC)\n"
	@bash packer/scripts/storage-provision.sh verify
	@printf "$(GREEN)>> Vérification terminée$(NC)\n"

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

.PHONY: vm-ensure vm-stop vm-start vm-delete image-id
.PHONY: marketplace-info marketplace-validate marketplace-all marketplace-test marketplace-tests

vm-ensure: ## Créer la VM de test SMW si elle n'existe pas (depuis dernière image gallery)
	@VM=$$(az vm list -g $(E2E_RG) --query "[?starts_with(name,'test-smw')].name | sort(@) | [-1]" -o tsv 2>/dev/null); \
	if [ -z "$$VM" ]; then \
		printf "$(YELLOW)  ➜ Aucune VM de test trouvée dans $(E2E_RG), création...$(NC)\n"; \
		IMAGE_ID=$$(az sig image-version list \
			--gallery-name $(GALLERY_NAME) \
			--gallery-image-definition $(GALLERY_IMAGE_NAME) \
			--resource-group $(GALLERY_RESOURCE_GROUP) \
			--query "sort_by(@, &publishingProfile.publishedDate)[-1].id" -o tsv 2>/dev/null); \
		if [ -z "$$IMAGE_ID" ]; then \
			printf "$(RED)  ✗ Aucune image dans $(GALLERY_NAME)/$(GALLERY_IMAGE_NAME)$(NC)\n"; exit 1; \
		fi; \
		VM_NAME="test-smw-$(BUILD_DATE)"; \
		printf "$(CYAN)  → Création VM: $$VM_NAME$(NC)\n"; \
		az vm create \
			--resource-group $(E2E_RG) \
			--name "$$VM_NAME" \
			--image "$$IMAGE_ID" \
			--size $(VM_SIZE) \
			--admin-username azureuser \
			--generate-ssh-keys \
			--public-ip-sku Standard \
			--output table; \
		printf "$(GREEN)  ✓ VM créée: $$VM_NAME$(NC)\n"; \
	else \
		printf "$(GREEN)  ✓ VM de test existante: $$VM$(NC)\n"; \
	fi

vm-stop: ## Deallocater la VM de test SMW
	@printf "$(CYAN)>> Arrêt de la VM de test...$(NC)\n"
	@VM=$$(az vm list -g $(E2E_RG) --query "[?starts_with(name,'test-smw')].name | sort(@) | [-1]" -o tsv 2>/dev/null); \
	if [ -z "$$VM" ]; then \
		printf "$(RED)  ✗ Aucune VM de test trouvée dans $(E2E_RG)$(NC)\n"; exit 1; \
	fi; \
	printf "$(CYAN)  → Deallocate: $$VM$(NC)\n"; \
	az vm deallocate -g $(E2E_RG) -n "$$VM" --no-wait; \
	printf "$(GREEN)  ✓ Arrêt lancé: $$VM$(NC)\n"

vm-start: ## Démarrer la VM de test SMW
	@printf "$(CYAN)>> Démarrage de la VM de test...$(NC)\n"
	@VM=$$(az vm list -g $(E2E_RG) --query "[?starts_with(name,'test-smw')].name | sort(@) | [-1]" -o tsv 2>/dev/null); \
	if [ -z "$$VM" ]; then \
		printf "$(RED)  ✗ Aucune VM de test trouvée dans $(E2E_RG)$(NC)\n"; exit 1; \
	fi; \
	printf "$(CYAN)  → Démarrage: $$VM$(NC)\n"; \
	az vm start -g $(E2E_RG) -n "$$VM"; \
	printf "$(GREEN)  ✓ VM démarrée: $$VM$(NC)\n"

vm-delete: ## Supprimer la VM de test SMW
	@printf "$(CYAN)>> Suppression de la VM de test...$(NC)\n"
	@VM=$$(az vm list -g $(E2E_RG) --query "[?starts_with(name,'test-smw')].name | sort(@) | [-1]" -o tsv 2>/dev/null); \
	if [ -z "$$VM" ]; then \
		printf "$(RED)  ✗ Aucune VM de test trouvée dans $(E2E_RG)$(NC)\n"; exit 1; \
	fi; \
	printf "$(CYAN)  → Suppression: $$VM$(NC)\n"; \
	az vm delete -g $(E2E_RG) -n "$$VM" --yes --no-wait; \
	printf "$(GREEN)  ✓ Suppression lancée: $$VM$(NC)\n"

image-id: ## Afficher l'ID et la version de la dernière image gallery
	@printf "$(CYAN)>> Récupération de l'ID de l'image...$(NC)\n"
	@IMAGE_ID=$$(az sig image-version list \
		--gallery-name $(GALLERY_NAME) \
		--gallery-image-definition $(GALLERY_IMAGE_NAME) \
		--resource-group $(GALLERY_RESOURCE_GROUP) \
		--query "sort_by(@, &publishingProfile.publishedDate)[-1].id" -o tsv 2>/dev/null); \
	if [ -z "$$IMAGE_ID" ]; then \
		printf "$(RED)  ✗ Aucune image dans $(GALLERY_NAME)/$(GALLERY_IMAGE_NAME)$(NC)\n"; exit 1; \
	fi; \
	VERSION=$$(az sig image-version list \
		--gallery-name $(GALLERY_NAME) \
		--gallery-image-definition $(GALLERY_IMAGE_NAME) \
		--resource-group $(GALLERY_RESOURCE_GROUP) \
		--query "sort_by(@, &publishingProfile.publishedDate)[-1].name" -o tsv 2>/dev/null); \
	printf "$(GREEN)  ✓ Version: $$VERSION$(NC)\n"; \
	printf "$(CYAN)  ID: $$IMAGE_ID$(NC)\n"

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

##@ Maintenance

.PHONY: clean
clean: ## Supprimer les fichiers générés (env/generated/, packer/generated.pkrvars.hcl)
	@printf "$(YELLOW)>> Nettoyage des fichiers générés...$(NC)\n"
	@rm -rf env/generated/
	@rm -f packer/generated.pkrvars.hcl
	@printf "$(GREEN)>> Nettoyage terminé$(NC)\n"
