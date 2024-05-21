#!/bin/sh

# Parse command line
args_list="help"
args_list="${args_list},build-images"
args_list="${args_list},verbose"

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo "Options:"
    echo "  --help              Show this help message and exit"
    echo "  --build-images      Optionally build the virtual cluster docker images."
    echo "  --verbose           Enable verbose mode"
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
    -h | --help)
        usage
        exit 1
        ;;
    --build-images)
        _build_images="--build-images"
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


sudo apt install -y make golang awscli

cd $HOME
mkdir capn-virtualcluster
cd capn-virtualcluster
git clone https://github.com/kubernetes-sigs/cluster-api-provider-nested.git
cd cluster-api-provider-nested/virtualcluster
make build WHAT=cmd/kubectl-vc
sudo cp -f _output/bin/kubectl-vc /usr/local/bin
cd $HOME

if [ -n "${_build_images:-}" ]; then
    cd $HOME/capn-virtualcluster/cluster-api-provider-nested/virtualcluster
    make build-images
    cd $HOME


    docker image ls
fi


