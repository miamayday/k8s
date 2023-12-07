#!/bin/sh

clean_up() {
  rm -f staging-pod.yml
  rm -rf "${tmp}"
}

trap exit SIGINT ERR
trap clean_up EXIT

usage_message="
Usage: ./${0##*/} [-fn]

Check persistent volume usage in cluster and optionally prepare volumes for backup.

  -f             Automatically spawn staging pods to mount standalone volumes in order to check usage.
  -n             Specify a namespace to reduce the scope of the operation to a single namespace.
  -h, --help     Print usage message.
  -v, --verbose  Enable verbose output.

Examples:

  # Check usage across all namespaces, require explicit permission for standalone volumes
  ./${0##*/}

  # Check usage in namespace 'kafka'
  ./${0##*/} -n kafka
"

usage() {
  echo "${usage_message}"
  exit 1
}

POSITIONAL_ARGS=()  # Arrays not supported by sh

force=false
scope=-A  # All namespaces in the cluster

while [ "${#}" -gt 0 ]
do
  case "${1}" in
    -f|--force)
      force=true
      shift
      ;;
    -n|--namespace)
      shift
      scope="-n ${1}"
      shift
      ;;
    -h|--help)
      usage
      ;;
    -v|--verbose)
      set -x
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("${1}")
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

set -eu

# e             Exit on fail
# u             Treat unset variables as errors
# x             Print every command
# o pipefail    Fail if one command in pipe fails

########### MAIN CODE STARTS HERE ###########

# Staging pod image
image='***'

tmp="$(mktemp -d)"
total=0
echo "${total}" > "${tmp}"/total

echo "Checking volumes mounted by running pods..."

pods="$(kubectl get po ${scope} -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name) \(.spec.volumes[].persistentVolumeClaim.claimName)"' | grep -v null || echo '')"

echo "${pods}" |
while IFS= read -r line
do
  [ -z "${line}" ] && continue
  namespace="$(echo "${line}" | cut -d' ' -f1)"
  pod="$(echo "${line}" | cut -d' ' -f2)"
  pvc="$(echo "${line}" | cut -d' ' -f3)"
  json="$(kubectl -n "${namespace}" get po "${pod}" -o json)"  # Reduce API calls
  vol="$(echo "${json}" | jq -r --arg pvc "${pvc}" '.spec.volumes[] | select(.persistentVolumeClaim.claimName==$pvc) | .name')"
  # Show volume usage
  container="$(echo "${json}" | jq -r --arg vol "${vol}" '.spec.containers[] | select(.volumeMounts[].name==$vol) | .name')"
  path="$(echo "${json}" | jq -r --arg container "${container}" --arg vol "${vol}" '.spec.containers[] | select(.name==$container) | .volumeMounts[] | select(.name==$vol) | .mountPath')"
  used="$(kubectl -n "${namespace}" exec "${pod}" -c "${container}" -- /bin/sh -c "df -k ${path}" | awk 'END {print $3}')"
  # Update total kibibytes
  total="$(cat "${tmp}"/total)"
  echo "$(( total + used ))" > "${tmp}"/total
  # Print used space in gibibytes
  gibibytes="$(echo "${used}*2^-20" | bc -l 2> /dev/null)"
  if [ "${?}" -eq 0 ]
  then
    printf '%s %s %s %s %.2fG\n' "${namespace}" "${pvc}" "${pod}" "${path}" "${gibibytes}"
  else
    printf '%s %s %s %s %d\n' "${namespace}" "${pvc}" "${pod}" "${path}" "${used}"
  fi
done

echo "Checking standalone volumes..."

cat > staging-pod.yml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: staging-pod
  annotations:
    backup.velero.io/backup-volumes: standalone-volume
spec:
  volumes:
    - name: standalone-volume
      persistentVolumeClaim:
        claimName: placeholder
  containers:
    - name: staging-container
      image: ${image}
      ports:
        - containerPort: 80
      volumeMounts:
        - mountPath: /standalone
          name: standalone-volume
EOF

pvcs="$(kubectl get pvc ${scope} -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"')"

echo "${pvcs}" |
while IFS= read -r line
do
  [ -z "${line}" ] && continue
  namespace="$(echo "${line}" | cut -d' ' -f1)"
  pvc="$(echo "${line}" | cut -d' ' -f2)"
  vols="$(kubectl -n "${namespace}" get po -o json | jq -r --arg pvc "${pvc}" '.items[].spec.volumes[] | select(.persistentVolumeClaim.claimName==$pvc) | .name')"
  [ ! -z "${vols}" ] && continue  # Ignore volumes mounted by pods
  # Request Create if [force: false]
  if [ "${force}" = false ]
  then
    read -p "Create a staging pod (for ${pvc}) in namespace '${namespace}'? (n) " create </dev/tty
    [ "${create}" != 'y' ] && continue  # Do not create staging pods without confirmation
  fi
  pod="${pvc}-staging-pod-$(shuf -i 1000-9999 -n1)"
  sed -r -e '/metadata:/{n;s|name:(.*)|name: '"${pod}"'|}' -e 's|claimName:(.*)|claimName: '"${pvc}"'|' staging-pod.yml > staging-pod.tmp && mv staging-pod.tmp staging-pod.yml
  kubectl -n "${namespace}" apply -f staging-pod.yml
  # Show volume usage
  kubectl -n "${namespace}" wait po "${pod}" --for=condition=Ready
  used="$(kubectl -n "${namespace}" exec "${pod}" -c staging-container -- /bin/sh -c 'df -k /standalone' | awk 'END {print $3}')"
  # Update total kibibytes
  total="$(cat "${tmp}"/total)"
  echo "$(( total + used ))" > "${tmp}"/total
  # Print used space in gibibytes
  gibibytes="$(echo "${used}*2^-20" | bc -l 2> /dev/null)"
  if [ "${?}" -eq 0 ]
  then
    printf '%s %s %s %s %.2fG\n' "${namespace}" "${pvc}" "${pod}" '/standalone' "${gibibytes}"
  else
    printf '%s %s %s %s %d\n' "${namespace}" "${pvc}" "${pod}" '/standalone' "${used}"
  fi
done

# Print total in gibibytes
total="$(cat "${tmp}"/total)"
gibibytes="$(echo "${total}*2^-20" | bc -l 2> /dev/null)"
if [ "${?}" -eq 0 ]
then
  printf 'Total: %.2fG\n' "${gibibytes}"
else
  printf 'Total: %d\n' "${total}"
fi
