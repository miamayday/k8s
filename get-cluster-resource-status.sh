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

printf 'NODE USED_CPU USED_MEM UNUSED_CPU UNUSED_MEM RESERVED_CPU UNRESERVED_CPU\n'

total_used_cpu_base=0
total_used_mem_gi=0
total_unused_cpu_base=0
total_unused_mem_gi=0
total_reserved_cpu_base=0
total_reserved_mem_gi=0
total_unused_cpu_base=0
while IFS= read -r node
do
  "${workspace}"/get-node-resource-status.sh "${node}" > status.tmp
  used_cpu_base="$(grep 'Used:' status.tmp | awk '{print $2}' | grep -oE '^(\.|[0-9])+')"
  used_mem_gi="$(grep 'Used:' status.tmp | awk '{print $4}' | grep -oE '^(\.|[0-9])+')"
  unused_cpu_base="$(grep 'Unused:' status.tmp | awk '{print $2}' | grep -oE '^(\.|[0-9])+')"
  unused_mem_gi="$(grep 'Unused:' status.tmp | awk '{print $4}' | grep -oE '^(\.|[0-9])+')"
  reserved_cpu_base="$(grep 'Reserved:' status.tmp | awk '{print $2}' | grep -oE '^(\.|[0-9])+')"
  reserved_mem_gi="$(grep 'Reserved:' status.tmp | awk '{print $4}' | grep -oE '^(\.|[0-9])+')"
  
  total_used_cpu_base="$(echo "${total_used_cpu_base}+${used_cpu_base}" | bc -l)"
  total_used_mem_gi="$(echo "${total_used_mem_gi}+${used_mem_gi}" | bc -l)"
  total_unused_cpu_base="$(echo "${total_unused_cpu_base}+${unused_cpu_base}" | bc -l)"
  total_unused_mem_gi="$(echo "${total_unused_mem_gi}+${unused_mem_gi}" | bc -l)"
  total_reserved_cpu_base="$(echo "${total_reserved_cpu_base}+${reserved_cpu_base}" | bc -l)"
  total_reserved_mem_gi="$(echo "${total_reserved_mem_gi}+${reserved_mem_gi}" | bc -l)"

  printf '%s %.1f %.2fGi %.1f %.2fGi %.1f %.2fGi\n' "${node}" "${used_cpu_base}" "${used_mem_gi}" "${unused_cpu_base}" "${unused_mem_gi}" "${reserved_cpu_base}" "${reserved_mem_gi}"
done < nodes.tmp

printf 'Total %.1f %.2fGi %.1f %.2fGi %.1f %.2fGi\n' "${total_used_cpu_base}" "${total_used_mem_gi}" "${total_unused_cpu_base}" "${total_unused_mem_gi}" "${total_reserved_cpu_base}" "${total_reserved_mem_gi}"
