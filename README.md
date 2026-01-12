# Kast-system Bookrack Template

A production-ready template repository for managing Kubernetes applications using the [kast-system](https://github.com/kast-spells/kast-system) GitOps framework with ArgoCD.

## What is this?

This template provides a pre-configured structure for deploying applications to Kubernetes using:

- **kast-system**: A declarative framework that extends ArgoCD with the Book/Chapter/Spell paradigm
- **ArgoCD**: GitOps continuous delivery tool for Kubernetes
- **Helm**: Package manager for Kubernetes applications

## Quick Start

### Prerequisites

- Kubernetes cluster (1.25+)
- kubectl configured and connected to your cluster
- Helm 3.8+
- Git 2.30+
- ArgoCD installed in your cluster

### 1. Use this template

Click "Use this template" on GitHub or clone this repository:

```bash
git clone https://github.com/kast-spells/bookrack-template.git my-bookrack
cd my-bookrack
```

### 2. Run setup script

```bash
./setup.sh
```

The script will prompt you for:
- Book name (e.g., `my-book`)
- Cluster name (e.g., `production`)
- Environment (e.g., `dev`, `staging`, `prod`)
- Git repository URL

### 3. Push to your repository

```bash
git remote set-url origin <your-new-repo-url>
git push -u origin main
```

### 4. Verify deployment

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check your spells
argocd app list -l argocd.argoproj.io/instance=<your-book-name>
```

## Repository Structure

```
.
├── bookrack/                    # Main directory for all books
│   └── example-book/           # A book (collection of related apps)
│       ├── index.yaml          # Book configuration
│       ├── infrastructure/     # Infrastructure chapter
│       │   ├── index.yaml      # Chapter configuration
│       │   └── redis.yaml      # Example infrastructure spell
│       └── applications/       # Applications chapter
│           ├── index.yaml      # Chapter configuration
│           ├── nginx-example.yaml
│           ├── app-with-secrets.yaml
│           └── app-with-istio.yaml
├── librarian/                  # Librarian helm chart (git submodule)
├── docs/                       # Documentation
├── setup.sh                    # Automated setup script
└── README.md                   # This file
```

## Core Concepts

### Book
A collection of related applications for a specific project or team. Each book has:
- Chapters (logical groupings)
- Global configuration (appendix)
- Shared trinkets (charts)

### Chapter
Logical grouping of applications within a book:
- `infrastructure`: foundational services (databases, caches, queues)
- `applications`: user-facing applications
- Custom chapters as needed

### Spell
Individual application definition (YAML file) describing:
- Container image and configuration
- Resources and scaling
- Networking (Service, Ingress)
- Health checks
- Integration with Vault, Istio, cert-manager, etc.

### Librarian
ArgoCD application that reads your books and generates ArgoCD Applications for each spell.

## Configuration Examples

### Simple Application Spell

```yaml
# bookrack/my-book/applications/webapp.yaml
name: webapp

image:
  name: nginx
  tag: latest
  pullPolicy: IfNotPresent

replicas: 2

ports:
  - name: http
    containerPort: 80

service:
  enabled: true
  type: ClusterIP
  ports:
    - name: http
      port: 80
```

### Application with Vault Secrets

```yaml
name: secure-app

vault:
  db-credentials:
    path: secret/data/production/database
    outputType: secret
    keys:
      - username
      - password

env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: username
```

### Application with Istio

```yaml
name: frontend

istio:
  frontend-vs:
    selector:
      access: external
    hosts:
      - app.example.com
    routes:
      - destination:
          host: frontend
          port: 80
```

## Book Configuration

Edit `bookrack/<your-book>/index.yaml` to customize:

### Cluster Information
```yaml
appendix:
  cluster:
    name: production
    environment: prod
    region: us-west-2
```

### Infrastructure Registry (Lexicon)
```yaml
appendix:
  lexicon:
    - name: external-gateway
      type: istio-gw
      labels:
        access: external
        default: book
      gateway: istio-system/external-gateway

    - name: vault-prod
      type: vault
      labels:
        default: book
      address: https://vault.vault.svc:8200
```

## Adding a New Application

1. Create a new spell file:
```bash
cat > bookrack/my-book/applications/myapp.yaml <<EOF
name: myapp
image:
  name: myapp
  tag: v1.0.0
replicas: 2
ports:
  - name: http
    containerPort: 8080
service:
  enabled: true
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: http
EOF
```

2. Commit and push:
```bash
git add bookrack/my-book/applications/myapp.yaml
git commit -m "Add myapp spell"
git push
```

3. ArgoCD will automatically detect and deploy (if auto-sync is enabled)

## Manual Operations

### Deploy Librarian Manually

```bash
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: librarian-my-book
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR-ORG/my-bookrack.git  # Your forked repo
    targetRevision: main
    path: librarian
    helm:
      values: |
        name: my-book
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

### Sync All Applications

```bash
# Sync all apps in a book
argocd app sync -l argocd.argoproj.io/instance=my-book

# Sync specific application
argocd app sync my-book-applications-nginx
```

### View Application Status

```bash
# List all applications
argocd app list

# Get application details
argocd app get my-book-applications-nginx

# Watch application sync
argocd app wait my-book-applications-nginx --health
```

## Troubleshooting

### Librarian not creating applications

Check librarian logs:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=librarian -f
```

### Application stuck in sync

Check ArgoCD application status:
```bash
argocd app get <app-name>
kubectl describe application <app-name> -n argocd
```

### Spell not being detected

Verify book/chapter/spell structure:
```bash
# Check if spell files are in correct location
find bookrack/ -name "*.yaml" -type f
```

## Advanced Features

### Multi-Environment Setup

Create separate books for each environment:
```
bookrack/
├── myapp-dev/
├── myapp-staging/
└── myapp-prod/
```

### Progressive Delivery with Argo Rollouts

```yaml
name: canary-app
workloadType: rollout

strategy:
  canary:
    steps:
      - setWeight: 20
      - pause: {duration: 1m}
      - setWeight: 50
      - pause: {duration: 2m}
      - setWeight: 100
```

### Custom Trinkets

Add custom Helm charts:
```yaml
trinkets:
  my-custom-chart:
    key: custom
    repository: https://my-repo.com/charts.git
    path: ./my-chart
    targetRevision: main
```

## Resources

- [kast-system Documentation](https://github.com/kast-spells/kast-system)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Contributing

This is a template repository. Fork it, customize it, and make it your own!

## License

MIT License - See LICENSE file for details

## Support

For issues with:
- **This template**: Open an issue in this repository
- **kast-system**: See [kast-system issues](https://github.com/kast-spells/kast-system/issues)
- **ArgoCD**: See [ArgoCD documentation](https://argo-cd.readthedocs.io/)
