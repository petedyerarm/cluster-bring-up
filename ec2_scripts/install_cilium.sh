#!/bin/sh

# Parse command line
args_list="dryrun"
args_list="${args_list},help"
args_list="${args_list},verbose"

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo "Options:"
    echo "  --help              Show this help message and exit"
    echo "  --dryrun            Enable dryrun mode"
    echo "  --verbose           Enable verbose mode"
}

drun() {
    if [ -n "${_dryrun:-}" ]; then
        echo "DRYRUN: $*"
    else
        $*
    fi
}

args=$(getopt -o+ho:x -l $args_list -n "$(basename "$0")" -- "$@")

# Check for getopt errors
if [ $? -ne 0 ]; then
    usage
    exit 1
fi

eval set -- "$args"

while [ $# -gt 0 ]; do
    if [ -n "${opt_prev:-}" ]; then
        eval "$opt_prev=\$1"
        opt_prev=
        shift 1
        continue
    elif [ -n "${opt_append:-}" ]; then
        eval "$opt_append=\"\${$opt_append:-} \$1\""
        opt_append=
        shift 1
        continue
    fi
    case $1 in
    --dryrun)
        _dryrun=$1
        ;;
    -h | --help)
        usage
        exit 1
        ;;
    --verbose)
        _verbose="--verbose"
        ;;
    --)
        shift
        break 2
        ;;
    esac
    shift 1
done

if [ -n "${_verbose:-}" ]; then
    set -x
fi

drun "curl -L --remote-name https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz"
drun "tar xzvf cilium-linux-amd64.tar.gz"
drun "sudo mv cilium /usr/local/bin/"
drun "rm cilium-linux-amd64.tar.gz"
drun "cilium install"

