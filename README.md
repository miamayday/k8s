# Kubernetes Guide

## Find applications by their environment variable

```bash
keyword=jdbc:postgresql
keyword=redis

# Find applications whose environment variable contains a keyword
kubectl get deploy,ds,sts -A -o json | jq -r --arg keyword "${keyword}" '.items[] | "\(.metadata.name) \(.spec.template.spec.containers[] | try .env[].value | select(contains($keyword)))"'

# Find pods whose environment variable contains a keyword
kubectl get po -A -o json | jq -r --arg keyword "${keyword}" '.items[] | "\(.metadata.name) \(.spec.containers[] | select(try .env[].value | contains($keyword)) | .name)"'

# Generate commands for checking logs of affected pods
kubectl get po -A -o json | jq -r --arg keyword "${keyword}" '.items[] | "kubectl -n \(.metadata.namespace) logs \(.metadata.name) -c \(.spec.containers[] | select(try .env[].value | contains($keyword)) | .name)"'

# Generate commands for filtering logs of affected pods
filter='error|warn|fail|exit|timeout|refuse|connect'
kubectl get po -A -o json | jq -r --arg keyword "${keyword}" --arg filter "${filter}" '.items[] | "kubectl -n \(.metadata.namespace) logs \(.metadata.name) -c \(.spec.containers[] | select(try .env[].value | contains($keyword)) | .name) | grep -iE \"\($filter)\""'
```

## Find applications by their ConfigMap

```bash
keyword=jdbc:postgresql
keyword=redis

# Find applications whose ConfigMap contains a keyword
kubectl get cm -A -o json | jq -r --arg keyword "${keyword}" '.items[] | select(try .data[] | contains($keyword)) | "\(.metadata.namespace) \(.metadata.annotations["meta.helm.sh/release-name"] | select(. != null))"'

# Generate commands for checking logs of affected pods (head -n1 assumes that volumes which mount the same configmap also share the same name)
kubectl get cm -A -o json | jq -r --arg keyword "${keyword}" '.items[] | select(try .data[] | contains($keyword)) | "\(.metadata.namespace) \(.metadata.name)"' | \
while read -r line ; \
do namespace="$(echo "${line}" | cut -d' ' -f1)" ; \
cm_name="$(echo "${line}" | cut -d' ' -f2)" ; \
vol_name="$(kubectl -n "${namespace}" get deploy,ds,sts -o json | jq -r --arg cm_name "${cm_name}" '.items[].spec.template.spec.volumes[] | select(.configMap.name == $cm_name) | .name' | head -n1)" ; \
kubectl -n "${namespace}" get po -o json | jq -r --arg cm_name "${cm_name}" --arg vol_name "${vol_name}" '.items[] | select(.spec.volumes[].configMap.name == $cm_name) | "kubectl -n \(.metadata.namespace) logs \(.metadata.name) -c \(.spec.containers[] | select(.volumeMounts[].name == $vol_name) | .name)"' ; \
done

# Generate commands for filtering logs of affected pods (head -n1 assumes that volumes which mount the same configmap also share the same name)
filter='error|warn|fail|exit|timeout|refuse|connect'
kubectl get cm -A -o json | jq -r --arg keyword "${keyword}" '.items[] | select(try .data[] | contains($keyword)) | "\(.metadata.namespace) \(.metadata.name)"' | \
while read -r line ; \
do namespace="$(echo "${line}" | cut -d' ' -f1)" ; \
cm_name="$(echo "${line}" | cut -d' ' -f2)" ; \
vol_name="$(kubectl -n "${namespace}" get deploy,ds,sts -o json | jq -r --arg cm_name "${cm_name}" '.items[].spec.template.spec.volumes[] | select(.configMap.name == $cm_name) | .name' | head -n1)" ; \
kubectl -n "${namespace}" get po -o json | jq -r --arg cm_name "${cm_name}" --arg vol_name "${vol_name}" --arg filter "${filter}" '.items[] | select(.spec.volumes[].configMap.name == $cm_name) | "kubectl -n \(.metadata.namespace) logs \(.metadata.name) -c \(.spec.containers[] | select(.volumeMounts[].name == $vol_name) | .name) | grep -iE \"\($filter)\""' ; \
done
```
