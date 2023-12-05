# Kubernetes Guide

## Find applications by their environment variables

```bash
# Find applications that use PostgreSQL
kubectl get deploy,ds,sts -A -o json | jq -r '.items[] | "\(.metadata.name) \(try .spec.template.spec.containers[].env[].value | select(contains("jdbc:postgresql")))"'

# Find pods that use PostgreSQL
kubectl get po -A -o json | jq -r '.items[] | "\(.metadata.name) \(try .spec.containers[].env[].value | select(contains("jdbc:postgresql")))"'

# Generate commands for checking logs of affected pods
kubectl get po -A -o json | jq -r '.items[] | "kubectl -n \(.metadata.namespace) logs \(.metadata.name) \(try .spec.containers[].env[].value | select(contains("jdbc:postgresql")))"' | cut -d' ' -f1-5 | uniq
```
