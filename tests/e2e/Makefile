# =============================================================================
# tests/e2e/Makefile
# Tests navigateur E2E — SMW Marketplace (Playwright / Firefox)
# =============================================================================
# Usage depuis ce répertoire :
#   make firefox           — Lancer les tests (VM_IP=<ip> optionnel)
#   make vm-e2e-create     — Créer la VM de test E2E (depuis dernière image gallery)
#   make vm-e2e-delete     — Supprimer la VM de test E2E
#   make vm-e2e-dns        — Assigner un label DNS à l'IP publique de la VM de test E2E
#   make vm-e2e-reboot     — Assigner le DNS et redémarrer la VM de test E2E
#   make vm-e2e-status     — Afficher l'état, l'IP et l'URL de la VM de test E2E
#
# Usage depuis la racine :
#   make e2e-browser                     ← VM_IP auto-détecté depuis Azure (E2E_RG)
#   make e2e-browser VM_IP=20.48.144.74  ← forcer une IP spécifique
#
# Dépendances npm : gérer depuis tests/ avec `make -C tests install`
# =============================================================================

E2E_RG    ?= rg-smw-marketplace-e2e
REPO_ROOT := $(CURDIR)/../..
VM_MANAGE := $(REPO_ROOT)/packer/scripts/vm-manage.sh
VM_IP     ?= $(shell E2E_RG=$(E2E_RG) bash $(VM_MANAGE) get-ip 2>/dev/null)
BUILD_DATE := $(shell date +%Y%m%d)
VM_MANAGE := $(REPO_ROOT)/packer/scripts/vm-manage.sh


# ---------------------------------------------------------------------------
# Couleurs (ADR-611)
# ---------------------------------------------------------------------------
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
NC     := \033[0m

define log_action
	@printf "$(CYAN)➤ $(1)$(NC)\n"
endef

# ---------------------------------------------------------------------------
# Cible par défaut
# ---------------------------------------------------------------------------
.DEFAULT_GOAL := firefox

.PHONY: firefox vm-e2e-create vm-e2e-delete vm-e2e-dns vm-e2e-reboot vm-e2e-status help

firefox: ## Lancer les tests navigateur Firefox (VM_IP=<ip|fqdn> si différent du défaut)
	$(call log_action,Tests navigateur Firefox — https://$(VM_IP)/...)
	@VM_IP=$(VM_IP) $(CURDIR)/../node_modules/.bin/playwright test \
		--config $(CURDIR)/playwright.config.js \
		--project firefox

vm-e2e-create: ## Créer la VM de test E2E depuis la dernière image gallery (E2E_RG=<rg>)
	$(call log_action,Vérification / création VM de test E2E...)
	@BUILD_DATE=$(BUILD_DATE) E2E_RG=$(E2E_RG) bash $(VM_MANAGE) ensure

vm-e2e-delete: ## Supprimer la VM de test E2E (E2E_RG=<rg>)
	$(call log_action,Suppression de la VM de test E2E...)
	@E2E_RG=$(E2E_RG) bash $(VM_MANAGE) delete

vm-e2e-dns: ## Assigner un label DNS à l'IP publique de la VM de test E2E (E2E_RG=<rg>)
	$(call log_action,Attribution label DNS à la VM de test E2E...)
	@E2E_RG=$(E2E_RG) bash $(VM_MANAGE) dns-assign

vm-e2e-reboot: ## Assigner le DNS puis redémarrer la VM de test E2E (E2E_RG=<rg>)
	$(call log_action,Attribution DNS + redémarrage de la VM de test E2E...)
	@E2E_RG=$(E2E_RG) bash $(VM_MANAGE) dns-assign-reboot

vm-e2e-status: ## Afficher l'état, l'IP, le DNS et l'URL de la VM de test E2E (E2E_RG=<rg>)
	$(call log_action,Statut de la VM de test E2E...)
	@E2E_RG=$(E2E_RG) bash $(VM_MANAGE) status

help: ## Afficher l'aide
	@printf "$(CYAN)Tests navigateur E2E — SMW Marketplace (Playwright / Firefox)$(NC)\n\n"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'
