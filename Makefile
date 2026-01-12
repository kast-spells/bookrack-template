# Makefile for kast-system bookrack operations

.PHONY: help init sync status clean deploy-librarian

# Default book name (override with: make sync BOOK=my-book)
BOOK ?= example-book

help: ## Show this help message
	@echo "Kast-system Bookrack Management"
	@echo ""
	@echo "Usage: make [target] [BOOK=book-name]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize git submodules for librarian
	@echo "Initializing submodules..."
	git submodule add https://github.com/kast-spells/librarian.git librarian 2>/dev/null || true
	git submodule update --init --recursive
	@echo "✓ Submodules initialized"

deploy-librarian: ## Deploy librarian for specified book
	@echo "Deploying librarian for book: $(BOOK)..."
	@if [ -z "$(REPO_URL)" ]; then \
		echo "Error: REPO_URL is required. Usage: make deploy-librarian BOOK=my-book REPO_URL=https://..."; \
		exit 1; \
	fi
	kubectl apply -f - <<EOF \
	apiVersion: argoproj.io/v1alpha1 \
	kind: Application \
	metadata: \
	  name: librarian-$(BOOK) \
	  namespace: argocd \
	spec: \
	  project: default \
	  source: \
	    repoURL: $(REPO_URL) \
	    targetRevision: main \
	    path: librarian \
	    helm: \
	      values: | \
	        name: $(BOOK) \
	  destination: \
	    server: https://kubernetes.default.svc \
	    namespace: argocd \
	  syncPolicy: \
	    automated: \
	      prune: true \
	      selfHeal: true \
	    syncOptions: \
	      - CreateNamespace=true \
	EOF
	@echo "✓ Librarian deployed"

sync: ## Sync all applications for specified book
	@echo "Syncing all applications for book: $(BOOK)..."
	argocd app sync -l argocd.argoproj.io/instance=$(BOOK)
	@echo "✓ Sync triggered"

sync-wait: ## Sync and wait for health for specified book
	@echo "Syncing and waiting for health for book: $(BOOK)..."
	argocd app sync -l argocd.argoproj.io/instance=$(BOOK)
	argocd app wait -l argocd.argoproj.io/instance=$(BOOK) --health
	@echo "✓ All applications healthy"

status: ## Show status of all applications for specified book
	@echo "Applications for book: $(BOOK)"
	@echo "========================================"
	@kubectl get applications -n argocd -l argocd.argoproj.io/instance=$(BOOK) \
		-o custom-columns=NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status
	@echo ""
	@echo "Use 'argocd app get <app-name>' for details"

list: ## List all applications across all books
	@echo "All Applications:"
	@echo "========================================"
	@kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status

logs: ## Show librarian logs for specified book
	@echo "Librarian logs for book: $(BOOK)..."
	kubectl logs -n argocd -l app.kubernetes.io/name=librarian-$(BOOK) --tail=100 -f

validate: ## Validate bookrack structure
	@echo "Validating bookrack structure..."
	@for book in bookrack/*/; do \
		if [ ! -f "$$book/index.yaml" ]; then \
			echo "✗ Missing index.yaml in $$book"; \
			exit 1; \
		fi; \
		echo "✓ $$book has valid structure"; \
	done
	@echo "✓ All books validated"

clean: ## Remove librarian for specified book
	@echo "Removing librarian for book: $(BOOK)..."
	kubectl delete application librarian-$(BOOK) -n argocd --ignore-not-found=true
	@echo "✓ Librarian removed"

clean-all: ## Remove all applications for specified book
	@echo "WARNING: This will remove all applications for book: $(BOOK)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		kubectl delete applications -n argocd -l argocd.argoproj.io/instance=$(BOOK); \
		echo "✓ All applications removed"; \
	else \
		echo "Cancelled"; \
	fi

diff: ## Show diff for specified book applications
	@echo "Showing diffs for book: $(BOOK)..."
	@argocd app diff -l argocd.argoproj.io/instance=$(BOOK)

refresh: ## Refresh applications for specified book
	@echo "Refreshing applications for book: $(BOOK)..."
	@for app in $$(kubectl get applications -n argocd -l argocd.argoproj.io/instance=$(BOOK) -o name); do \
		argocd app get $$app --refresh > /dev/null 2>&1; \
	done
	@echo "✓ Applications refreshed"

watch: ## Watch application status for specified book
	@echo "Watching applications for book: $(BOOK) (Ctrl+C to stop)..."
	@watch -n 2 "kubectl get applications -n argocd -l argocd.argoproj.io/instance=$(BOOK) -o custom-columns=NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status"

setup: ## Run setup script
	./setup.sh

check: ## Check prerequisites
	@echo "Checking prerequisites..."
	@command -v git >/dev/null 2>&1 || (echo "✗ git not found" && exit 1)
	@echo "✓ git: $$(git --version)"
	@command -v kubectl >/dev/null 2>&1 || (echo "✗ kubectl not found" && exit 1)
	@echo "✓ kubectl: $$(kubectl version --client --short 2>/dev/null)"
	@command -v helm >/dev/null 2>&1 || (echo "✗ helm not found" && exit 1)
	@echo "✓ helm: $$(helm version --short)"
	@command -v argocd >/dev/null 2>&1 || (echo "⚠ argocd CLI not found (optional)")
	@kubectl cluster-info >/dev/null 2>&1 || (echo "✗ Cannot connect to Kubernetes" && exit 1)
	@echo "✓ Connected to Kubernetes cluster"
	@kubectl get namespace argocd >/dev/null 2>&1 || (echo "⚠ ArgoCD namespace not found")
	@echo "✓ All prerequisites satisfied"
