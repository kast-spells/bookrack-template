# Quick Start Guide

Get up and running with kast-system in 5 minutes.

## Prerequisites Check

```bash
# Check Kubernetes connection
kubectl cluster-info

# Check ArgoCD installation
kubectl get pods -n argocd

# Check required tools
kubectl version --client
helm version
git --version
```

## Step 1: Clone and Setup (2 minutes)

```bash
# Clone the template repository
git clone https://github.com/kast-spells/bookrack-template.git my-bookrack
cd my-bookrack

# Initialize librarian submodule
git submodule add https://github.com/kast-spells/librarian.git librarian
git submodule update --init --recursive
```

## Step 2: Configure Your Book (1 minute)

```bash
# Rename the example book
mv bookrack/example-book bookrack/my-book

# Update book name
sed -i 's/name: example-book/name: my-book/' bookrack/my-book/index.yaml

# Update cluster info
sed -i 's/name: my-cluster/name: production/' bookrack/my-book/index.yaml
sed -i 's/environment: dev/environment: prod/' bookrack/my-book/index.yaml
```

## Step 3: Deploy Librarian (1 minute)

```bash
# Replace with your forked repository URL
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
    syncOptions:
      - CreateNamespace=true
EOF
```

## Step 4: Verify Deployment (1 minute)

```bash
# Check librarian status
kubectl get application -n argocd librarian-my-book

# Wait for applications to be created
watch kubectl get applications -n argocd

# Check your deployed applications
argocd app list

# Sync all applications
argocd app sync -l argocd.argoproj.io/instance=my-book
```

## Step 5: Access Your Applications

```bash
# List all services
kubectl get svc -n my-book-applications

# Port-forward to test
kubectl port-forward -n my-book-applications svc/nginx-example 8080:80

# Test in browser or curl
curl http://localhost:8080
```

## What's Next?

### Add Your First Application

```bash
# Create a new spell
cat > bookrack/my-book/applications/hello-world.yaml <<'EOF'
name: hello-world
image:
  name: nginx
  tag: alpine
replicas: 1
ports:
  - name: http
    containerPort: 80
service:
  enabled: true
  type: ClusterIP
  ports:
    - name: http
      port: 80
EOF

# Commit and push
git add bookrack/my-book/applications/hello-world.yaml
git commit -m "Add hello-world application"
git push

# ArgoCD will auto-sync (if enabled) or sync manually:
argocd app sync my-book-applications-hello-world
```

### Customize Examples

1. Edit `bookrack/my-book/applications/nginx-example.yaml`
2. Change replica count, image tag, or resources
3. Commit and push
4. Watch ArgoCD deploy your changes

### Add Secrets with Vault

1. Uncomment vault configuration in `bookrack/my-book/index.yaml`
2. Add vault trinket to lexicon
3. Use `app-with-secrets.yaml` as example
4. Deploy and verify

### Enable Istio Integration

1. Uncomment Istio gateway in lexicon
2. Use `app-with-istio.yaml` as example
3. Deploy and verify virtual service

## Troubleshooting

### Applications not appearing?

```bash
# Check librarian logs
kubectl logs -n argocd -l app.kubernetes.io/name=librarian

# Verify book structure
find bookrack/ -name "*.yaml"
```

### Sync errors?

```bash
# Check application status
argocd app get <app-name>

# View events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Need help?

- Check the main [README.md](../README.md)
- Review [kast-system documentation](https://github.com/kast-spells/kast-system)
- Open an issue in this repository
