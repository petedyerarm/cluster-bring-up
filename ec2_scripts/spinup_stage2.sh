#!/bin/sh

k8sver=v1.29
k8ssubver=3

# Parse command line
args_list="dryrun"
args_list="${args_list},help"
args_list="${args_list},version:"
args_list="${args_list},subver:"
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
    --subver)
        opt_prev=k8ssubver
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

sudo wget https://github.com/containerd/containerd/releases/download/v1.7.13/containerd-1.7.13-linux-amd64.tar.gz -P /tmp
sudo tar Cxzvf /usr/local /tmp/containerd-1.7.13-linux-amd64.tar.gz

sudo wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -P /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

sudo wget https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64 -P /tmp
sudo install -m 755 /tmp/runc.amd64 /usr/local/sbin/runc


sudo wget https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz -P /tmp
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin /tmp/cni-plugins-linux-amd64-v1.4.0.tgz

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl restart containerd



sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gpg

sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/$k8sver/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$k8sver/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet=$k8sver.$k8ssubver-1.1 kubeadm=$k8sver.$k8ssubver-1.1 kubectl=$k8sver.$k8ssubver-1.1
sudo apt-mark hold kubelet kubeadm kubectl


