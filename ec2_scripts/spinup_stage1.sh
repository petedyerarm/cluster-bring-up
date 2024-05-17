#!/bin/sh

# Parse command line
args_list="dryrun"
args_list="${args_list},help"
args_list="${args_list},hostname:"
args_list="${args_list},verbose"

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo "Options:"
    echo "  --help              Show this help message and exit"
    echo "  --hostname  <name>  Specify the hostname"
    echo "  --dryrun            Enable dryrun mode"
    echo "  --verbose           Enable verbose mode"
}

drun() {
    if [ -n "${_dryrun:-}" ]; then
        echo "DRYRUN: $*"
    else
        exit 1
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
    --hostname)
        opt_prev=__HOST_NAME__
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

if [ -z "${__HOST_NAME__:-}" ]; then
  printf "error: missing parameter --hostname hostname\n" >&2
  exit 3
fi

drun "sudo hostnamectl set-hostname $__HOST_NAME__"
drun "sudo apt-get update  && sudo apt upgrade -y"
drun "sudo apt install -y docker.io"
drun "sudo usermod -aG docker $USER"
drun "sudo reboot"
