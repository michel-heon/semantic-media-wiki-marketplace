# =============================================================================
# tests/integration/Makefile
# Orchestrateur des tests d'intégration — SMW Marketplace
# =============================================================================
# ADR-700 — Plan de Tests d'Intégration
# ADR-602 — Makefile = orchestrateur uniquement (logique → packer/scripts/*.sh)
# ADR-611 — @printf uniquement, jamais @echo -e
#
# Usage depuis ce répertoire :
#   make static    — Phase 1 : tests statiques (aucun accès Azure)
#   make image     — Phase 2 : tests image gallery via SSH
#   make e2e       — Phase 3 : tests E2E post-déploiement ARM
#   make all       — Suite complète
#
# Usage depuis la racine du projet :
#   make -C tests/integration static
# =============================================================================

REPO_ROOT := $(shell cd ../.. && pwd)
SCRIPT    := $(REPO_ROOT)/packer/scripts/integration-test.sh

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
.DEFAULT_GOAL := static

.PHONY: static image e2e all help

static: ## Phase 1 — Tests statiques : HCL2, ARM JSON, scan secrets, permissions (aucun accès Azure)
	$(call log_action,Tests statiques — Phase 1...)
	@bash $(SCRIPT) static

image: ## Phase 2 — Tests image gallery via SSH (E2E_RG et VM_NAME requis)
	$(call log_action,Tests image gallery — Phase 2...)
	@bash $(SCRIPT) image

e2e: ## Phase 3 — Tests E2E post-déploiement ARM (firstboot déclenché)
	$(call log_action,Tests E2E post-déploiement — Phase 3...)
	@bash $(SCRIPT) e2e

all: ## Suite complète : Phase 1 (static) + Phase 2 (image) + Phase 3 (e2e)
	$(call log_action,Suite de tests d integration complète — Phases 1 + 2 + 3...)
	@bash $(SCRIPT) all

help: ## Afficher l'aide
	@printf "$(CYAN)Tests d'intégration — SMW Marketplace (ADR-700)$(NC)\n\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-12s$(NC) %s\n", $$1, $$2}'
