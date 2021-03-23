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
  local START_CMD=($(jq -r --arg key "$APP_NAME" '.[$key].startcmd' < ./test/app-args.json))
  log "starting app $APP_NAME with cmd "$START_CMD". Will retry 5 times."
  # Execute the command 
  retry 5 ${START_CMD[@]}

  log "Beginning to poll until pod enters Running status"
  retry 10 is_pod_running

  #TODO: more verification on app now that it is running
  log "Curling the app"
  curl -I $(jq -r .hostname < test/app-args.json)/$APP_NAME

  verify_app
  log "Smoke tests passed for app $APP_NAME"
}

function is_pod_running() {
  local POD_STATUS=$(kubectl get pod -n $APP_NAME-ns | grep $APP_NAME | awk '{print $3}')
  log "pod status is currently $POD_STATUS"
  if [[ $POD_STATUS == "Running" ]]; then
    log "Successfully polled pod for $APP_NAME until Running status."
  else
    log "Pod is not in Running status yet, returning exit code 1"
    return 1
  fi
}

function verify_app() {
  local URL=$(jq -r .hostname < test/app-args.json)/$APP_NAME
  local STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" $URL)
  if [[ $STATUS_CODE -eq 200 ]]; then 
    log "Status code $URL endpoint is 200"
  else 
    log "Status code for $URL is $STATUS_CODE. Test failed."
    exit 1
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