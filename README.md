# Kubernetes Guide

## Find applications by their environment variables

```bash
# Find applications that use PostgreSQL
kubectl get deploy,ds,sts -A -o json | jq -r '.items[] | "\(.metadata.name) \(.spec.template.spec.containers[] | try .env[].value | select(. != null) | select(match("jdbc:postgresql")))"'

# Find pods that use PostgreSQL
kubectl get po -A -o json | jq -r '.items[] | "\(.metadata.name) \(.spec.containers[] | try .env[].value | select(. != null) | select(match("jdbc:postgresql")))"'

# Generate commands for checking logs of affected pods
kubectl get po -A -o json | jq -r '.items[] | select(.spec.containers[] | try .env[].value | select(. != null) | select(match("jdbc:postgresql"))) | "kubectl -n \(.metadata.namespace) logs \(.metadata.name)"'

# Find applications that use Redis
kubectl get deploy,ds,sts -A -o json | jq -r '.items[] | "\(.metadata.name) \(.spec.template.spec.containers[] | try .env[].value | select(. != null) | select(match("redis")))"'

# Find pods that use Redis
kubectl get po -A -o json | jq -r '.items[] | "\(.metadata.name) \(.spec.containers[] | try .env[].value | select(. != null) | select(match("redis")))"'

# Generate commands for checking logs of affected pods
kubectl get po -A -o json | jq -r '.items[] | select(.spec.containers[] | try .env[].value | select(. != null) | select(match("redis"))) | "kubectl -n \(.metadata.namespace) logs \(.metadata.name)"'
```
