# =============================================================================
# tests/e2e/Makefile
# Tests navigateur E2E — SMW Marketplace (Playwright / Firefox)
# =============================================================================
# Usage depuis ce répertoire :
#   make install    — Installer les dépendances npm + Firefox (via tests/Makefile)
#   make firefox    — Lancer les tests (VM_IP=<ip> optionnel)
#   make all        — install + firefox
#
# Usage depuis la racine :
#   make e2e-browser VM_IP=20.48.144.74
# =============================================================================

REPO_ROOT := $(shell cd ../.. && pwd)
VM_IP     ?= 20.48.144.74

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

.PHONY: install firefox all help

install: ## Installer @playwright/test + le navigateur Firefox (délégué à tests/Makefile)
	$(call log_action,Installation des dépendances npm (délégué à tests/)...)
	@$(MAKE) -C $(CURDIR)/.. install --no-print-directory

firefox: ## Lancer les tests navigateur Firefox (VM_IP=<ip> si différent du défaut)
	$(call log_action,Tests navigateur Firefox — https://$(VM_IP)/...)
	@VM_IP=$(VM_IP) $(CURDIR)/../node_modules/.bin/playwright test \
		--config $(CURDIR)/playwright.config.js \
		--project firefox

all: install firefox ## Installer Firefox + lancer les tests

help: ## Afficher l'aide
	@printf "$(CYAN)Tests navigateur E2E — SMW Marketplace (Playwright / Firefox)$(NC)\n\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'
