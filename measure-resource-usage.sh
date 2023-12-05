#!/bin/sh

namespace="${1}"

log=log.csv

kubectl -n "${namespace}" top pod --no-headers | while read IFS= -r line ; do cfdfbfg
