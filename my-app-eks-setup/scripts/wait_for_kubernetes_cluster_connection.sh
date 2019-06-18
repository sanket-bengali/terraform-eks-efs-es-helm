#!/bin/bash
set -e

wait_for_kubernetes_cluster_endpoint_connection() {
  cluster_endpoint=$1
  wait_timeout=$2
  end="$((SECONDS+wait_timeout))"
  #echo "Waiting for connection to Kubernetes cluster endpoint : ${cluster_endpoint}"
  #echo "Timeout (seconds) : $wait_timeout"
  while true; do
    response_code=$(curl -ksw %{http_code} --connect-timeout 10 --max-time 10 -o /dev/null ${cluster_endpoint})
    #echo "Response code : $response_code"
    [[ "403" = "$response_code" ]] && exit_code=0 && break
    [[ "${SECONDS}" -ge "${end}" ]] && exit_code=1 && break
    sleep 5
  done

  if [[ "$exit_code" == 0 ]]
  then
       connection="PASS"
  else
       connection="FAIL"
  fi

  jq -n --arg connection "$connection" '{"connection": $connection}'
}

eval "$(jq -r '@sh "CLUSTER_ENDPOINT=\(.cluster_endpoint) TIMEOUT=\(.timeout)"')"

wait_for_kubernetes_cluster_endpoint_connection ${CLUSTER_ENDPOINT} ${TIMEOUT}
