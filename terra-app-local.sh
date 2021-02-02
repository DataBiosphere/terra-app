#!/bin/bash

###
### Parameters
###
readonly progname="$(basename "${0}")"
readonly progdir="$(readlink "$(dirname "${0}")")"
readonly args=("$@")

# Set bash shell options
set -e

###
### Functions
###
usage() {

    cat <<USAGEEOF
${progname} deploys an app on a local minikube cluster.

 Find more information at: https://github.com/DataBiosphere/terra-app

Usage:
  ${progname} [command]

Available commands:
  install       installs an app
  uninstall     deletes an app
  status        displays stats about an app
  list          lists all apps
  show-kubectl  prints kubectl commands to interact with an app

Flags:
  -h, --help    display help

Use "${progname} [command] --help" for more information about a command.
USAGEEOF
}

install_usage() {
    cat <<USAGEEOF
Install an app to a locally running minikube cluster.

 For more information about configuring minikube, see: https://github.com/DataBiosphere/terra-app

Usage:
  ${progname} install -f [filename] -a [extra args] ...

Flags:
  -a, --arg       optional. extra args to the app launch command. can be repeated.
  -f, --filename  path to the app descriptor file
  -h, --help      display help
USAGEEOF
}

install() {
    local _filename
    local _args=()

    if [ -z "$1" ]; then
        install_usage
        exit 0
    fi

    while [ "$1" != "" ]; do
        case "$1" in
            -a | --arg)
                shift
                _args+=($1)
                ;;
            -f | --filename)
                shift
                _filename=$1
                ;;
            -h | --help)
                install_usage
                exit 0
                ;;
            *)
                echo "Unrecognized argument '${1}'."
                echo "Run '${progname} install --help' to see available arguments."
                exit 1
                ;;
        esac
        shift
    done

    if [ -z "${_filename}" ]; then
        echo "Error: -f needs an argument."
        echo "Run '${progname} install --help' to see available arguments."
        exit 1
    fi

    if ! test -f "${_filename}"; then
        echo "Error: file '${_filename}' does not exist."
        exit 1
    fi

    # get minikube ip
    local _minikube_ip=$(minikube ip)
    if [ -z "${_minikube_ip}" ]; then
       echo "Unable to retrieve minikube public IP. Is minikube running?"
       exit 1
    fi

    install_nginx
    install_app "${_filename}" "${_args[@]}"

    echo ""
    echo "Congratulations! Your app has been installed on minikube."
    echo ""
    echo "To poll application startup, do one or more of the following:"
    echo ""
    echo " kubectl get pod -n ${_namespace}"
    echo " kubectl describe pod -n ${_namespace} [pod-name]"
    echo " kubectl logs -n ${_namespace} [pod-name]"
    echo ""
    echo "Once the pod is RUNNING, do the following to open the app:"
    echo ""
    echo "1. Add an entry to your /etc/hosts:"
    echo "     ${_minikube_ip}  k8s.app.info"
    echo ""
    echo "2. Load this URL in a browser:"
    echo "     http://k8s.app.info/${_appname}/"
    echo ""
}

install_nginx() {
    echo "Setting up nginx ingress controller..."

    # check if nginx namespace exists
    if ! kubectl get ns | grep -q nginx; then
        kubectl create namespace nginx
    fi
    
    # check if we need to add the nginx helm repo
    if ! helm show chart center/stable/nginx-ingress --version 1.41.3 >/dev/null 2>&1; then
        helm repo add center https://repo.chartcenter.io --force-update > /dev/null
        helm repo update >/dev/null
    fi

    # install nginx
    helm upgrade --install nginx center/stable/nginx-ingress \
      -n nginx \
      --version 1.41.3 \
      --set rbac.create=true \
      --set controller.publishService.enabled=true \
      --set controller.service.externalIPs[0]="${_minikube_ip}" >/dev/null 2>&1
}

# note only single-service apps are currently supported
install_app() {
    # read args
    local _filename="$1"
    local _extraargs="$2"
   
    # parse information out of the descriptor
    _appname=$(yq e '.name' "${_filename}")
    _namespace="${_appname}-ns"
    local _ksa="${_appname}-ksa"
    local _ingresspath="/${_appname}(/|$)(.*)"

    if [ -z "${_appname}" ] | [ "${_appname}" == "null" ] ; then
        echo "Error: could not parse app name from file '${_filename}'."
        exit 1
    fi

    echo "Installing '${_appname}' from descriptor file '${_filename}'..."
 
    # create the namespace if it doesn't already exist
    if ! kubectl get ns | grep -q "${_namespace}"; then
        kubectl create namespace "${_namespace}"
    fi

    # create KSA if it doesn't already exist
    if ! kubectl get serviceaccount -n "${_namespace}" | grep -q "${_appname_ksa}"; then
        kubectl create serviceaccount --namespace "${_namespace}" "${_appname_ksa}"
    fi

    echo "${_env}"

    # build values yaml from app descriptor 
    # note this supports at most 3 EVs; I couldn't figure out how to make yq map over keys
    local _tmp_values=$(mktemp)
    yq e \
      ".nameOverride=.name \
      | .image.image=.services.*.image \
      | .image.port=.services.*.port \
      | .image.command=.services.*.command \
      | .image.args=.services.*.args \
      | .ingress.hosts[0].paths[0]=\"${_ingresspath}\" \
      | .persistence.hostPath=\"/data\" \
      | .configs=.services.*.environment \
      | .extraEnv[0].name=(.configs | keys | .[0]) \
      | .extraEnv[0].valueFrom.configMapKeyRef.name=\"${_appname}-${_appname}-configs\" \
      | .extraEnv[0].valueFrom.configMapKeyRef.key=(.configs | keys | .[0])' \
      | .extraEnv[1].name=(.configs | keys | .[1]) \
      | .extraEnv[1].valueFrom.configMapKeyRef.name=\"${_appname}-${_appname}-configs\" \
      | .extraEnv[1].valueFrom.configMapKeyRef.key=(.configs | keys | .[1])' \
      | .extraEnv[2].name=(.configs | keys | .[2]) \
      | .extraEnv[2].valueFrom.configMapKeyRef.name=\"${_appname}-${_appname}-configs\" \
      | .extraEnv[2].valueFrom.configMapKeyRef.key=(.configs | keys | .[2])' \
      | del(.name) \
      | del(.services)" "${_filename}" > "${_tmp_values}"

    # apply extra args, if any
    for a in "${_extraargs[@]}"; do
        yq e -i ".image.args += \"$a\"" "${_tmp_values}"
    done    

    #echo "Installing chart with values:"
    #cat "${_tmp_values}"
    #echo ""
    
    # install the app
    helm upgrade --install -n "${_namespace}" \
      "${_appname}" \
      chart/ \
      -f "${_tmp_values}"
}

main() {
    local _subcmd
    local _subcmd_args
    
    if [ -z "$1" ]; then
        usage
        exit 0
    fi

    while [ "$1" != "" ]; do
        case "$1" in
            install | uninstall | status | list | show-kubectl)
                _subcmd="$1"
                shift
                _subcmd_args=("$@")
                break
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                echo "Unrecognized command '${1}'."
                echo "Run '${progname} --help' to see available arguments."
                exit 1
                ;;
        esac
        shift
    done

    if [ "${_subcmd}" == "install" ]; then
        install "${_subcmd_args[@]}"
    else
        echo "Unrecognized command '${_subcmd}'."
        echo "Run '${progname} --help' to see available arguments."
        exit 1
    fi
}
        
###
### Main
###

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "${args[@]}"
fi
