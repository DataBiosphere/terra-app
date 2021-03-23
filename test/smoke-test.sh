#!/bin/bash
# Usage ./smoke-test.sh [app-name]
# Should be run at the top-level folder
# See app-args.json top-level keys for valid app names

set -e

function run_test() {
  if [[ -z $1 ]]; then
    echo "Program requires an argument. Exiting..."
    echo "Usage: ./test/smoke-test.sh [app_name]"
    exit 1
  fi

  # intentionally global, other functions use this
  APP_NAME=$1

  # Extract command from config file as an array
  local START_CMD=($(jq -r .$APP_NAME.startcmd < ./test/app-args.json))
  log "starting app $APP_NAME with cmd "$START_CMD". Will retry 5 times."
  # Execute the command 
  retry 5 ${START_CMD[@]}

  log "Beginning to poll until pod enters Running status"
  retry 10 is_pod_running

  #TODO: more verification on app now that it is running
  log "Smoke tests passed for app $APP_NAME"
}


function is_pod_running() {
  local POD_STATUS=$(kubectl get pod -n $APP_NAME-ns | grep $APP_NAME | awk '{print $3}')
  log "pod status is currently $POD_STATUS"
  if [[ $POD_STATUS == "Running" ]]; then
    log "Successfully polled pod for $APP_NAME until Running status"
    return 0
  else
    log "Pod is not in Running status yet, exiting 1"
    return 1
  fi
}

function log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@"
}

# Retry a command up to a specific number of times until it exits successfully,
# with exponential back off. For example:
#
#   $ retry 5 echo "Hello"
#     Hello
#
#   $ retry 5 false
#     Retry 1/5 exited 1, retrying in 2 seconds...
#     Retry 2/5 exited 1, retrying in 4 seconds...
#     Retry 3/5 exited 1, retrying in 8 seconds...
#     Retry 4/5 exited 1, retrying in 16 seconds...
#     Retry 5/5 exited 1, no more retries left.
function retry() {
  local retries=$1
  shift

  for ((i = 1; i <= $retries; i++)); do
    # run with an 'or' so set -e doesn't abort the bash script on errors
    exit=0
    "$@" || exit=$?
    if [ $exit -eq 0 ]; then
      return 0
    fi
    wait=$((2 ** $i))
    if [ $i -eq $retries ]; then
      log "Retry $i/$retries exited $exit, no more retries left."
      break
    fi
    log "Retry $i/$retries exited $exit, retrying in $wait seconds..."
    sleep $wait
  done
  return 1
}
run_test $@
