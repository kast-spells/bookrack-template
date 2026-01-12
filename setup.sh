#!/usr/bin/env bash
# Bookrack Template Setup Script
# This script initializes the kast-system bookrack for a new environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."

    command -v git >/dev/null 2>&1 || error "git is not installed"
    command -v kubectl >/dev/null 2>&1 || error "kubectl is not installed"
    command -v helm >/dev/null 2>&1 || error "helm is not installed"

    # Check kubectl connection
    kubectl cluster-info >/dev/null 2>&1 || error "Cannot connect to Kubernetes cluster"

    info "All prerequisites satisfied ✓"
}

# Initialize submodules
init_submodules() {
    info "Initializing librarian submodule..."

    if [ ! -d "librarian/.git" ]; then
        git submodule add https://github.com/kast-spells/librarian.git librarian 2>/dev/null || true
        git submodule update --init --recursive
        info "Submodule initialized ✓"
    else
        warn "Submodule already initialized"
        git submodule update --recursive
    fi
}

# Rename example book
rename_book() {
    local book_name=$1

    if [ -d "bookrack/${book_name}" ]; then
        warn "Book '${book_name}' already exists, skipping rename"
        return
    fi

    info "Renaming example-book to ${book_name}..."
    mv bookrack/example-book "bookrack/${book_name}"

    # Update book name in index.yaml
    sed -i.bak "s/name: example-book/name: ${book_name}/" "bookrack/${book_name}/index.yaml"
    rm -f "bookrack/${book_name}/index.yaml.bak"

    info "Book renamed ✓"
}

# Update cluster configuration
update_cluster_config() {
    local book_name=$1
    local cluster_name=$2
    local environment=$3

    info "Updating cluster configuration..."

    local index_file="bookrack/${book_name}/index.yaml"

    sed -i.bak "s/name: my-cluster/name: ${cluster_name}/" "${index_file}"
    sed -i.bak "s/environment: dev/environment: ${environment}/" "${index_file}"
    rm -f "${index_file}.bak"

    info "Cluster configuration updated ✓"
}

# Deploy librarian to ArgoCD
deploy_librarian() {
    local book_name=$1
    local repo_url=$2

    info "Deploying librarian for book: ${book_name}..."

    # Detect current branch
    local target_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "master")
    info "Using branch: ${target_branch}"

    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: librarian-${book_name}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${repo_url}
    targetRevision: ${target_branch}
    path: librarian
    helm:
      values: |
        name: ${book_name}
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

    info "Librarian deployed ✓"
    info "Run 'kubectl get application -n argocd' to check status"
}

# Main setup flow
main() {
    echo "================================================"
    echo "    Kast-system Bookrack Template Setup"
    echo "================================================"
    echo ""

    check_prerequisites

    # Detect Git repository URL automatically
    REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")

    # Interactive prompts
    read -p "Enter book name (e.g., my-book): " BOOK_NAME
    BOOK_NAME=${BOOK_NAME:-my-book}

    read -p "Enter cluster name (e.g., production): " CLUSTER_NAME
    CLUSTER_NAME=${CLUSTER_NAME:-my-cluster}

    read -p "Enter environment (dev/staging/prod): " ENVIRONMENT
    ENVIRONMENT=${ENVIRONMENT:-dev}

    if [ -n "${REPO_URL}" ]; then
        info "Detected repository URL: ${REPO_URL}"
        read -p "Use this repository URL? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter Git repository URL (for librarian): " REPO_URL
        fi
    else
        read -p "Enter Git repository URL (for librarian): " REPO_URL
    fi

    echo ""
    info "Configuration:"
    echo "  Book name: ${BOOK_NAME}"
    echo "  Cluster: ${CLUSTER_NAME}"
    echo "  Environment: ${ENVIRONMENT}"
    echo "  Repository: ${REPO_URL}"
    echo ""

    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Setup cancelled"
    fi

    # Execute setup steps
    init_submodules
    rename_book "${BOOK_NAME}"
    update_cluster_config "${BOOK_NAME}" "${CLUSTER_NAME}" "${ENVIRONMENT}"

    # Commit changes
    info "Committing changes..."
    git add .
    git commit -m "Initial setup: ${BOOK_NAME} for ${CLUSTER_NAME} (${ENVIRONMENT})" || warn "Nothing to commit"

    # Optionally deploy librarian
    read -p "Deploy librarian to ArgoCD now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -z "${REPO_URL}" ]; then
            error "Repository URL is required to deploy librarian"
        fi
        deploy_librarian "${BOOK_NAME}" "${REPO_URL}"
    else
        info "Skipping librarian deployment"
        info "You can deploy later using: kubectl apply -f docs/librarian-bootstrap.yaml"
    fi

    echo ""
    info "Setup complete! 🎉"
    echo ""
    info "Next steps:"
    echo "  1. Review and customize bookrack/${BOOK_NAME}/index.yaml"
    echo "  2. Add your application spells in bookrack/${BOOK_NAME}/applications/"
    echo "  3. Push to remote: git remote set-url origin <your-fork-url> && git push -u origin main"
    echo "  4. Sync ArgoCD applications: argocd app sync -l argocd.argoproj.io/instance=${BOOK_NAME}"
}

# Run main function
main "$@"
