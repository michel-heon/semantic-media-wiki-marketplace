# =============================================================================
# tests/user-smoke/Makefile
# Smoke tests utilisateur SMW — Playwright / Firefox
# =============================================================================
# Usage depuis ce répertoire :
#   make smoke             — Lancer les smoke tests (VM_IP=<ip|fqdn> optionnel)
#
# Usage depuis la racine :
#   make user-smoke                     ← VM_IP auto-détecté depuis Azure (E2E_RG)
#   make user-smoke VM_IP=20.48.144.74  ← forcer une IP spécifique
#   make user-smoke VM_IP=smw-test-20260518.canadacentral.cloudapp.azure.com
#
# Variables d'environnement :
#   VM_IP              — IP ou FQDN de la VM cible (auto-détecté depuis Azure si absent)
#   SMW_ADMIN_USER     — Chargé depuis tests/user-smoke/env (voir env.example)
#   SMW_ADMIN_PASSWORD — Chargé depuis tests/user-smoke/env (voir env.example)
#
# Dépendances npm : gérer depuis tests/ avec `make -C tests install`
# =============================================================================

E2E_RG    ?= rg-smw-marketplace-e2e
REPO_ROOT := $(CURDIR)/../..
VM_MANAGE := $(REPO_ROOT)/packer/scripts/vm-manage.sh
VM_IP     ?= $(shell E2E_RG=$(E2E_RG) bash $(VM_MANAGE) get-ip 2>/dev/null)

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
	@set -a; . $(CURDIR)/env; set +a; VM_IP=$(VM_IP) $(CURDIR)/../node_modules/.bin/playwright test \
		--config $(CURDIR)/playwright.config.js \
		--project firefox

help: ## Afficher cette aide
	@printf "$(CYAN)Smoke tests utilisateur SMW — cibles disponibles :$(NC)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
