#!/bin/sh

workspace="$(dirname "${0}")"

add_to_total() {
  addition="${1}"
  total_file="${2}"
  total="$(cat "${total_file}" 2> /dev/null || echo 0)"
  total="$(echo "${total}+${addition}" | bc -l)"
  echo "${total}" > "${total_file}"
}

kubectl get node | tail -n +2 | awk '{print $1}' > "${workspace}"/nodes.tmp

while IFS= read -r node
do
  "${workspace}"/get-node-resource-status.sh "${node}" > status.tmp
done < nodes.tmp

exit

printf "Total

rm -f reserved_cpu_base.total reserved_mem_gi.total used_cpu_base.total used_mem_gi.total
