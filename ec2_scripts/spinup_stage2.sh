#!/bin/sh

k8sver=v1.29

# Parse command line
args_list="dryrun"
args_list="${args_list},help"
args_list="${args_list},version:"
args_list="${args_list},verbose"

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo "Options:"
    echo "  --help                    Show this help message and exit"
    echo "  --dryrun                  Enable dryrun mode"
    echo "  --version <k8s-version>   Enable verbose mode"
    echo "  --verbose                 Enable verbose mode"
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
    --version)
        opt_prev=k8sver
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


sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/$k8sver/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$k8sver/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "source <(kubeadm completion bash)" >> ~/.bashrc
source <(kubectl completion bash)
source <(kubeadm completion bash)
