#!/bin/sh

convert_cpu_to_base() {
  amount="$(echo "${1}" | grep -oE '^(\.|[0-9])+')"
  unit="$(echo "${1}" | grep -oE '([a-z]|[A-Z])+$')"
  if [ -z "${unit}" ]
  then
    echo "${amount}"
  elif [ "${unit}" = 'm' ]
  then
    echo "${amount}/1000" | bc -l
  else
    echo "Unknown unit: ${unit}"
  fi
}

convert_mem_to_gi() {
  amount="$(echo "${1}" | grep -oE '^(\.|[0-9])+')"
  unit="$(echo "${1}" | grep -oE '([a-z]|[A-Z])+$')"
  if [ -z "${unit}" ]  # bytes
  then
    echo "${amount}*2^-30" | bc -l
  elif [ "${unit}" = 'K' ] || [ "${unit}" = 'Ki' ]  # kibibytes
  then
    echo "${amount}*2^-20" | bc -l
  elif [ "${unit}" = 'M' ] || [ "${unit}" = 'Mi' ]  # mebibytes
  then
    echo "${amount}*2^-10" | bc -l
  elif [ "${unit}" = 'G' ] || [ "${unit}" = 'Gi' ]  # gibibytes
  then
    echo "${amount}"
  else
    echo "Unknown unit: ${unit}"
  fi
}

node="${1}"

status="$(kubectl get node "${node}" -o json | jq -r '.status')"

capacity="$(echo "${status}" | jq -r '.capacity')"
capacity_cpu="$(echo "${capacity}" | jq -r '.cpu')"
capacity_cpu_base="$(convert_cpu_to_base "${capacity_cpu}")"
capacity_mem="$(echo "${capacity}" | jq -r '.memory')"
capacity_mem_gi="$(convert_mem_to_gi "${capacity_mem}")"

# Capacity = Allocatable + kube-reserved + system-reserved + eviction-threshold
printf 'Capacity: %.1f CPU %.2fGi RAM\n' "${capacity_cpu_base}" "${capacity_mem_gi}"

allocatable="$(echo "${status}" | jq -r '.allocatable')"
allocatable_cpu="$(echo "${allocatable}" | jq -r '.cpu')"
allocatable_cpu_base="$(convert_cpu_to_base "${allocatable_cpu}")"
allocatable_mem="$(echo "${allocatable}" | jq -r '.memory')"
allocatable_mem_gi="$(convert_mem_to_gi "${allocatable_mem}")"

# Allocatable = Capacity - kube-reserved - system-reserved - eviction-threshold
printf 'Allocatable: %.1f CPU %.2fGi RAM\n' "${allocatable_cpu_base}" "${allocatable_mem_gi}"

allocated="$(kubectl describe node "${node}" | grep 'Allocated resources:' -A5 | tail -n2)"
reserved_cpu="$(echo "${allocated}" | awk '/cpu/ {print $2}')"  # cpu-requests (must not exceed capacity)
reserved_cpu_base="$(convert_cpu_to_base "${reserved_cpu}")"
reserved_mem="$(echo "${allocated}" | awk '/memory/ {print $2}')"  # mem-requests (must not exceed capacity)
reserved_mem_gi="$(convert_mem_to_gi "${reserved_mem}")"

printf 'Reserved: %.1f CPU %.2fGi RAM\n' "${reserved_cpu_base}" "${reserved_mem_gi}"

unreserved_cpu_base="$(echo "${capacity_cpu_base}-${reserved_cpu_base}" | bc -l)"
unreserved_mem_gi="$(echo "${capacity_mem_gi}-${reserved_mem_gi}" | bc -l)"

printf 'Unreserved: %.1f CPU %.2fGi RAM\n' "${unreserved_cpu_base}" "${unreserved_mem_gi}"

used="$(kubectl top node | grep "${node}")"
used_cpu="$(echo "${used}" | awk '{print $2}')"
used_cpu_base="$(convert_cpu_to_base "${used_cpu}")"
used_mem="$(echo "${used}" | awk '{print $4}')"
used_mem_gi="$(convert_mem_to_gi "${used_mem}")"

printf 'Used: %.1f CPU %.2fGi RAM\n' "${used_cpu_base}" "${used_mem_gi}"

unused_cpu_base="$(echo "${allocatable_cpu_base}-${used_cpu_base}" | bc -l)"
unused_mem_gi="$(echo "${allocatable_mem_gi}-${used_mem_gi}" | bc -l)"

printf 'Unused: %.1f CPU %.2fGi RAM\n' "${unused_cpu_base}" "${unused_mem_gi}"
