# =============================================================================
# tests/user-smoke/Makefile
# Smoke tests utilisateur SMW — Playwright / Firefox
# =============================================================================
# Usage depuis ce répertoire :
#   make smoke             — Lancer les smoke tests (VM_IP=<ip|fqdn> optionnel)
#
# Usage depuis la racine :
#   make user-smoke VM_IP=20.48.144.74
#   make user-smoke VM_IP=smw-test-20260518.canadacentral.cloudapp.azure.com
#
# Variables d'environnement :
#   VM_IP              — IP ou FQDN de la VM cible (défaut : 20.48.144.74)
#   SMW_ADMIN_USER     — Utilisateur admin MediaWiki (défaut : WikiAdmin)
#   SMW_ADMIN_PASSWORD — Mot de passe admin MediaWiki (défaut : ChangeMe123!)
#
# Dépendances npm : gérer depuis tests/ avec `make -C tests install`
# =============================================================================

VM_IP     ?= 20.48.144.74
E2E_RG    ?= rg-smw-marketplace-e2e
REPO_ROOT := $(CURDIR)/../..

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
.DEFAULT_GOAL := smoke

.PHONY: smoke help

smoke: ## Lancer les smoke tests utilisateur SMW (VM_IP=<ip|fqdn> si différent du défaut)
	$(call log_action,Smoke tests utilisateur SMW — https://$(VM_IP)/wiki/Special:Ask ...)
	@VM_IP=$(VM_IP) $(CURDIR)/../node_modules/.bin/playwright test \
		--config $(CURDIR)/playwright.config.js \
		--project firefox

help: ## Afficher cette aide
	@printf "$(CYAN)Smoke tests utilisateur SMW — cibles disponibles :$(NC)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
