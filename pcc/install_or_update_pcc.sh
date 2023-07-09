#!/usr/bin/env bash

set -euo pipefail -o errtrace

BASE_DIR=$HOME
TYPE=false
SKIP_DEPENDENCY_INSTALLATION=false

usage(){
    echo "Usage: $(basename "${0}") [-d <BASE_DIRECTORY>] [-t <TYPE>]"
    echo "Installs or updates pcc on a raspberry pi. https://github.com/dasl-/pcc"
    echo "  -d BASE_DIRECTORY : Base directory in which to download files. Trailing slash optional."
    echo "                      Defaults to $BASE_DIR."
    echo "  -t TYPE           : Installation type: either 'controller', 'receiver', or 'all'"
    echo "  -s                : Skip dependency installation step (faster: deps aren't always necessary on subsequent runs)"
    echo "  -h                : Print this help message"
    exit 1
}

main(){
    trap 'fail $? $LINENO' ERR

    parseOpts "$@"

    cloneOrPullRepo "$BASE_DIR/pcc" "git@github.com:dasl-/pcc.git"
    pushd "$BASE_DIR/pcc"
    if [[ ${SKIP_DEPENDENCY_INSTALLATION} == "false" ]]; then
        ./install/install_dependencies.sh -t $TYPE
    fi
    ./install/install.sh -t $TYPE
    popd

    info "Success!"
}

parseOpts(){
    while getopts ":d:t:hs" opt; do
        case ${opt} in
            d)
                BASE_DIR=${OPTARG%/} ;; # remove trailing slash if present
            t) TYPE=${OPTARG} ;;
            s) SKIP_DEPENDENCY_INSTALLATION=true ;;
            \?)
                warn "Invalid option: -$OPTARG"
                usage
                ;;
            :)
                warn "Option -$OPTARG requires an argument."
                usage
                ;;
            *) usage ;;
        esac
    done
}

cloneOrPullRepo(){
    local repo_path="$1"
    local clone_url="$2"
    local git_cmd='GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git'
    local this_git_cmd=''

    mkdir -p "$BASE_DIR"
    if [ ! -d "$repo_path" ]
    then
        info "Cloning repo: $clone_url into $repo_path ..."
        this_git_cmd="$git_cmd clone $clone_url $repo_path"
        eval "$this_git_cmd"
    else
        info "Pulling repo in $repo_path ..."
        this_git_cmd="$git_cmd -C $repo_path pull"
        eval "$this_git_cmd"
    fi
}

fail(){
    local exit_code=$1
    local line_no=$2
    local script_name
    script_name=$(basename "${BASH_SOURCE[0]}")
    die "Error in $script_name at line number: $line_no with exit code: $exit_code"
}

info(){
    echo -e "\x1b[32m$*\x1b[0m" # green stdout
}

warn(){
    echo -e "\x1b[33m$*\x1b[0m" # yellow stdout
}

die(){
    echo
    echo -e "\x1b[31m$*\x1b[0m" >&2 # red stderr
    exit 1
}

main "$@"
