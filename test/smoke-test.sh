#!/bin/bash
# This program depends on terra-app-local.sh, and all the dependencies listed there
# This program is intended to be run in an automated workflow to smoke test all 'supported' apps
# If `terra-app-local.sh` is working for a given app, this script should as well.
#   It is NOT POSSIBLE to run this locally on MAC because it does not support the only minikube driver (`none`) allowed in github actions
#   See https://github.com/actions/virtual-environments/issues/183https://github.com/actions/virtual-environments/issues/183
# Usage ./smoke-test.sh [app-name]
# Should be run at the top-level folder
# See ci-config.json top-level keys for valid app names

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
  local START_CMD=($(jq -r --arg key "$APP_NAME" '.[$key].startcmd' < ci-config.json))
  local MOUNT_FILE=$(jq -r --arg key1 "$APP_NAME" '.[$key1]."mount-file"' < ci-config.json)
  if [[ ! $MOUNT_FILE == "null" ]]; then 
    START_CMD+=("-a $PWD/$MOUNT_FILE"); 
  fi

  log "starting app $APP_NAME with cmd (${START_CMD[@]}) with retries"
  retry 5 ${START_CMD[@]}

  log "Beginning to poll until pod enters Running status"
  retry 9 is_pod_running

  retry 5 verify_app
  log "Smoke tests passed for app $APP_NAME"
}

function is_pod_running() {
  local POD_STATUS=$(kubectl get pod -n $APP_NAME-ns | grep $APP_NAME | awk '{print $3}')
  log "pod status is currently $POD_STATUS"
  if [[ $POD_STATUS == "Running" ]]; then
    log "Successfully polled pod for $APP_NAME until Running status."
  else
    log "Pod is not in Running status yet, returning exit code 1. Printing pod logs..."
    return 1
  fi
}

function verify_app() {
  local EXPECTED_STATUS_CODE=$(jq -r --arg key1 "$APP_NAME" '.[$key1]."expected-status-code"' < ci-config.json)
  local URL=$(jq -r .hostname < ci-config.json)/$APP_NAME
  local ACTUAL_STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" $URL)
  if [[ $ACTUAL_STATUS_CODE -eq $EXPECTED_STATUS_CODE ]]; then 
    log "SUCCESS. Status code for app $APP_NAME at url $URL is as expected: $ACTUAL_STATUS_CODE"
    return 0
  else 
    log "FAILED. Status code for app $APP_NAME at url $URL is $ACTUAL_STATUS_CODE. Expected $EXPECTED_STATUS_CODE. Printing pod logs.."
    print_pod_logs
    return 1
  fi
}

function log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@"
}

function print_pod_logs {
  kubectl logs -n $APP_NAME-ns $(kubectl get pod -n $APP_NAME-ns | grep -m 1 $APP_NAME | awk '{print $1}')
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
