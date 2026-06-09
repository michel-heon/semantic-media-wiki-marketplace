# =============================================================================
# tests/Makefile
# Gestion npm partagée pour toutes les suites de tests
# =============================================================================
# Usage :
#   make install        — npm install + browsers Playwright
#   make update         — npm update (mettre à jour les dépendances)
#   make clean          — Supprimer node_modules/
#   make browsers       — (Re)installer les navigateurs Playwright
#   make help           — Afficher l'aide
# =============================================================================

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

define log_success
	@printf "$(GREEN)  ✓ $(1)$(NC)\n"
endef

define log_warning
	@printf "$(YELLOW)⚠ $(1)$(NC)\n"
endef

# ---------------------------------------------------------------------------
# Cible par défaut
# ---------------------------------------------------------------------------
.DEFAULT_GOAL := install

.PHONY: install update clean browsers help

install: ## Installer les dépendances npm + les navigateurs Playwright
	$(call log_action,Installation des dépendances npm (tests/)...)
	@npm install --prefix $(CURDIR)
	$(call log_action,Installation des navigateurs Playwright...)
	@$(CURDIR)/node_modules/.bin/playwright install firefox
	$(call log_success,Dépendances npm + navigateurs installés)

update: ## Mettre à jour les dépendances npm
	$(call log_action,Mise à jour des dépendances npm...)
	@npm update --prefix $(CURDIR)
	$(call log_success,Dépendances npm mises à jour)

browsers: ## (Re)installer les navigateurs Playwright
	$(call log_action,Installation des navigateurs Playwright...)
	@$(CURDIR)/node_modules/.bin/playwright install firefox
	$(call log_success,Navigateurs installés)

clean: ## Supprimer node_modules/
	$(call log_warning,Suppression de tests/node_modules/...)
	@rm -rf $(CURDIR)/node_modules
	$(call log_success,node_modules/ supprimé)

help: ## Afficher l'aide
	@printf "$(CYAN)Gestion npm partagée — tests/$(NC)\n\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'
