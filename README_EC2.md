# To create a k8s cluster on an EC2 instance


## Create 3 instances via the webui

Ubuntu Server 22.04  
Enable SSH from anywhere  
t3.medium  
Add a KeyPair for SSH access (you need the pem file later for ssh access)  
Increase disk to 16Gb

### Add security groups

Enable the ports provided in 

K8S_MASTER:  
https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#SecurityGroup:groupId=sg-0be0d730391c35a63


## Update instances


NOTE: These steps are automated in the [ec2_scripts](https://github.com/petedyerarm/cluster-bring-up/tree/main/ec2_scripts)  
Run [spinup_stage1.sh](https://github.com/petedyerarm/cluster-bring-up/tree/main/ec2_scripts/spinup-stage1.sh) first, followed by [spinup_stage2.sh](https://github.com/petedyerarm/cluster-bring-up/tree/main/ec2_scripts/spinup_stage2.sh)


### k8s-control

#### Update the node name, the packages and install docker.  
The reboot is needed got the update to use the newer kernel version.

```bash
ssh -i /path/to/your/key.pem ubuntu@<public-ip> 
sudo hostnamectl set-hostname k8s-control
sudo apt-get update  && sudo apt upgrade -y
sudo apt install -y docker.io
sudo usermod -aG docker $USER
sudo reboot
```

#### Configure for k8s

```bash
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
sudo systemctl enable containerd


sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gpg

sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/$k8sver/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$k8sver/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet=1.29.1-1.1 kubeadm=1.29.1-1.1 kubectl=1.29.1-1.1
sudo apt-mark hold kubelet kubeadm kubectl
```

#### Create cluster
This is provided in [init_cluster.sh](https://github.com/petedyerarm/cluster-bring-up/tree/main/ec2_scripts/init_cluster.sh)  

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "source <(kubeadm completion bash)" >> ~/.bashrc
source <(kubectl completion bash)
source <(kubeadm completion bash)
```

If cluster initialisation has succeeded, then we will see a cluster join command. This command will be used by the worker nodes to join the Kubernetes cluster, so copy this command and save it for joining the worker nodes later. 

If you lose the join information, you can regenerate it using the following command:
```bash
kubeadm token create --print-join-command
```


#### Install calico CNI
This is provided in [install_calico.sh](https://github.com/petedyerarm/cluster-bring-up/tree/main/ec2_scripts/install_calico.sh)


```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
```


### k8s-worker nodes

#### Update the node name, the packages and install docker.  
The reboot is needed got the update to use the newer kernel version.

The node name should be unique, so change NN for a number.  

```bash
ssh -i /path/to/your/key.pem ubuntu@<public-ip> 
sudo hostnamectl set-hostname k8s-worker-NN
sudo apt-get update  && sudo apt upgrade -y
sudo reboot
```

#### Configure for k8s

```bash
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
sudo systemctl enable containerd


sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gpg

sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/$k8sver/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$k8sver/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet=1.29.1-1.1 kubeadm=1.29.1-1.1 kubectl=1.29.1-1.1
sudo apt-mark hold kubelet kubeadm kubectl
```

#### Join cluster
Run the kubeadm join command that we have received and saved.

