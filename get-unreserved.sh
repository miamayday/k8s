#!/bin/sh

clean_up() {
  [ ! -z "${tmp+x}" ] && rm -rf "${tmp}"
}

trap exit SIGINT ERR
trap clean_up EXIT

usage_message="
Usage: ./${0##*/}

Get unreserved resources in cluster.
  -h, --help     Print usage message.
  -v, --verbose  Enable verbose output.
"

usage() {
  echo "${usage_message}"
  exit 1
}

POSITIONAL_ARGS=''  # Arrays not supported in POSIX

while [ "${#}" -gt 0 ]
do
  case "${1}" in
    -h|--help)
      usage
      ;;
    -v|--verbose)
      set -x
      shift
      ;;
    *)
      POSITIONAL_ARGS+="${1} "
      shift
      ;;
  esac
done

set -- ${POSITIONAL_ARGS}  # Interpret as separate arguments; do not use double quotes

set -euo pipefail

# e             Exit on fail
# u             Treat unset variables as errors
# x             Print every command
# o pipefail    Fail if one command in pipe fails

########### MAIN CODE STARTS HERE ###########

workspace="$(CDPATH= cd -- "$(dirname -- "${0}")" && pwd)"

tmp="$(mktemp -d)"

add_to_total() {
  addition="${1}"
  total_file="${2}"
  total="$(cat "${total_file}" 2> /dev/null || echo 0)"
  total="$(echo "${total}+${addition}" | bc -l)"
  echo "${total}" > "${total_file}"
}

kubectl get node | tail -n +2 | awk '{print $1}' > "${tmp}"/nodes

printf 'NODE UNRESERVED_CPU UNRESERVED_MEM\n' > "${tmp}"/output

total_unreserved_cpu_base=0
total_unreserved_mem_gi=0
while IFS= read -r node
do
  "${workspace}"/get-node-resource-status.sh "${node}" > "${tmp}"/status
  unreserved_cpu_base="$(grep 'Unreserved:' "${tmp}"/status | awk '{print $2}' | grep -oE '^(\.|[0-9])+')"
  unreserved_mem_gi="$(grep 'Unreserved:' "${tmp}"/status | awk '{print $4}' | grep -oE '^(\.|[0-9])+')"
  total_unreserved_cpu_base="$(echo "${total_unreserved_cpu_base}+${unreserved_cpu_base}" | bc -l)"
  total_unreserved_mem_gi="$(echo "${total_unreserved_mem_gi}+${unreserved_mem_gi}" | bc -l)"
  printf '%s %.1f %.2fGi\n' "${node}" "${unreserved_cpu_base}" "${unreserved_mem_gi}" >> "${tmp}"/output
done < "${tmp}"/nodes

printf 'Total %.1f %.2fGi\n' "${total_unreserved_cpu_base}" "${total_unreserved_mem_gi}" >> "${tmp}"/output

column -t "${tmp}"/output
