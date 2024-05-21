# To install virtual-cluster


## 1. Build and install `kubectl-vc`

VirtualCluster offers a handy `kubectl` plugin, we can build and use it by following this process.
```bash
sudo apt install -y make golang awscli

mkdir capn-virtualcluster
cd capn-virtualcluster
git clone https://github.com/kubernetes-sigs/cluster-api-provider-nested.git
cd cluster-api-provider-nested/virtualcluster
make build WHAT=cmd/kubectl-vc
sudo cp -f _output/bin/kubectl-vc /usr/local/bin
cd
```
And then you can manage VirtualCluster by `kubectl vc` command tool which will be used to create virtualcluster later on.


## 2. Build the virtualcluster images and upload them to your repository of choice (Optional)

The default setup of the yaml file is to pull the required component to run virtualcluster from the dockerhub repository. It seems that the image on the dockerhub repository is not up to date, thus building the image from source and upload it your own repository is required.

We use the makefile that is already create on the repository to build the necessary images.

```bash
$ make build-images
make: /usr/local/kubebuilder/bin/kube-apiserver: Command not found < # We are going to ignore this for now
hack/make-rules/release-images.sh 
Building sigs.k8s.io/cluster-api-provider-nested/virtualcluster/cmd/manager
Building sigs.k8s.io/cluster-api-provider-nested/virtualcluster/cmd/syncer
Building sigs.k8s.io/cluster-api-provider-nested/virtualcluster/cmd/vn-agent
Building sigs.k8s.io/cluster-api-provider-nested/virtualcluster/cmd/kubectl-vc

Starting docker build for image: manager-amd64
Starting docker build for image: syncer-amd64
Starting docker build for image: vn-agent-amd64
Docker builds done
```

This will build these 3 images.

1. virtualcluster/manager-amd64
2. virtualcluster/syncer-amd64
3. virtualcluster/vn-agent-amd64

Upload them to an image repository of your choosing.

## 3. Create Virtual Cluster

Update $HOME/.aws/credentials and $HOME/.aws/config for your AWS account. 

#### Create namespace
``` bash
kubectl create ns vc-manager
```

#### Create secret
NOTE - the docker-server details below are for the Dev-IL account, region eu-north-1
``` bash
kubectl create secret docker-registry awsecr --docker-server=580140558762.dkr.ecr.eu-north-1.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password) -n vc-manager
```
#### Install CRD.
``` bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-nested/main/virtualcluster/config/crd/tenancy.x-k8s.io_clusterversions.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-nested/main/virtualcluster/config/crd/tenancy.x-k8s.io_virtualclusters.yaml
```

#### Create Virtual Cluster Components
``` bash
kubectl create -f /home/ubuntu/cluster-bring-up/virtual-cluster/all_in_one_private_repo_no_namespace_creation.yaml
```

Check what we have


```bash
# A dedicated namespace named "vc-manager" is created
$ kubectl get ns
NAME              STATUS   AGE
default           Active   14m
kube-node-lease   Active   14m
kube-public       Active   14m
kube-system       Active   14m
vc-manager        Active   74s

# And the components, including vc-manager, vc-syncer and vn-agent are installed within namespace `vc-manager`
$ kubectl get all -n vc-manager
NAME                              READY   STATUS    RESTARTS   AGE
pod/vc-manager-76c5878465-mv4nv   1/1     Running   0          92s
pod/vc-syncer-55c5bc5898-v4hv5    1/1     Running   0          92s
pod/vn-agent-d9dp2                1/1     Running   0          92s

NAME                                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/virtualcluster-webhook-service   ClusterIP   10.106.26.51   <none>        9443/TCP   76s

NAME                      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/vn-agent   1         1         1       1            1           <none>          92s

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/vc-manager   1/1     1            1           92s
deployment.apps/vc-syncer    1/1     1            1           92s

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/vc-manager-76c5878465   1         1         1       92s
replicaset.apps/vc-syncer-55c5bc5898    1         1         1       92s
```

## Create ClusterVersion

A `ClusterVersion` CR specifies how the tenant control-plane(s) will be configured, as a template for tenant control-planes' components.

The following cmd will create a `ClusterVersion` named `cv-sample-np`, which specifies the tenant control-plane components as:
- `etcd`: a StatefulSet with `k8s.gcr.io/etcd:3.5.6-0` image, 1 replica;
- `apiServer`: a StatefulSet with `registry.k8s.io/kube-apiserver:v1.29.3` image, 1 replica;
- `controllerManager`: a StatefulSet with `registry.k8s.io/kube-controller-manager:v1.29.3` image, 1 replica.

```bash
#Refer to the share yaml file.

kubectl create -f clusterversion_v1_nodeport_sb_test.yaml

```

#### Create Virtual Cluster
``` bash
kubectl vc create -f /home/ubuntu/capn-virtualcluster/cluster-api-provider-nested/virtualcluster/config/sampleswithspec/virtualcluster_1_nodeport.yaml -o vc-1.kubeconfig
```
> Note that tenant control plane does not have scheduler installed. The Pods are still scheduled as usual in super control plane.

## Create VirtualCluster

We can now create a `VirtualCluster` CR, which refers to the `ClusterVersion` that we just created.

The `vc-manager` will create a tenant control plane, where its tenant apiserver can be exposed through nodeport, or load balancer.

```bash
kubectl vc create -f /home/ubuntu/capn-virtualcluster/cluster-api-provider-nested/virtualcluster/config/sampleswithspec/virtualcluster_1_nodeport.yaml -o vc-1.kubeconfig
```

example output

```bash
2024/04/03 13:04:38 etcd is ready
2024/04/03 13:04:48 apiserver is ready
2024/04/03 13:04:50 controller-manager is ready
2024/04/03 13:04:50 VirtualCluster default/vc-sample-1 setup successfully
```

The command will create a tenant control plane named `vc-sample-1`, exposed by NodePort.

Once it's created, a kubeconfig file specified by `-o`, namely `vc-1.kubeconfig`, will be created in the current directory.


## Access Virtual Cluster

The generated `vc-1.kubeconfig` can be used as a normal `kubeconfig` to access the tenant virtual cluster.


Now let's take a look how Virtual Cluster looks like:

```bash
# A dedicated API Server, of course the <IP>:<PORT> may vary
$ kubectl cluster-info --kubeconfig vc-1.kubeconfig
Kubernetes control plane is running at  https://10.0.158.239:31480 

# Looks exactly like a vanilla Kubernetes
$ kubectl get namespace --kubeconfig vc-1.kubeconfig
NAME              STATUS   AGE
default           Active   9m11s
kube-node-lease   Active   9m13s
kube-public       Active   9m13s
kube-system       Active   9m13s
```

But from the super control plane angle, we can see something different:

```bash
$ kubectl get namespace
NAME                                         STATUS   AGE
calico-apiserver                             Active   13d
calico-system                                Active   13d
default                                      Active   13d
default-ff5078-vc-sample-1                   Active   110s
default-ff5078-vc-sample-1-default           Active   77s
default-ff5078-vc-sample-1-kube-node-lease   Active   77s
default-ff5078-vc-sample-1-kube-public       Active   77s
default-ff5078-vc-sample-1-kube-system       Active   77s
kube-node-lease                              Active   13d
kube-public                                  Active   13d
kube-system                                  Active   13d
tigera-operator                              Active   13d
vc-manager                                   Active   7m2s
```

## Let's do some experiments

From now on, we can view the virtual cluster as a normal cluster to work with.

Firstly, let's create a deployment.

```bash
$ kubectl apply --kubeconfig vc-1.kubeconfig -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deploy
  labels:
    app: vc-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vc-test
  template:
    metadata:
      labels:
        app: vc-test
    spec:
      containers:
      - name: poc
        image: busybox
        command:
        - top
EOF
```

Upon successful creation, there are newly Pods created.

We can view it from the tenant control plane:

```bash
$ kubectl get pod --kubeconfig vc-1.kubeconfig
NAME                           READY   STATUS    RESTARTS   AGE
test-deploy-6f6658f8cf-xd4g5   1/1     Running   0          25s
```

Or from the super control plane:

```bash 
$ VC_NAMESPACE="$(kubectl get VirtualCluster vc-sample-1 -o json | jq -r '.status.clusterNamespace')"
$ kubectl get pod -n "${VC_NAMESPACE}-default"

NAME                           READY   STATUS    RESTARTS   AGE
test-deploy-6f6658f8cf-xd4g5   1/1     Running   0          50s
```

Also, a new virtual node is created in the tenant control plane but the tenant cannot schedule Pods on it.

```bash
$ kubectl get node --kubeconfig vc-1.kubeconfig
NAME             STATUS                     ROLES    AGE   VERSION
meta-worker-01   Ready,SchedulingDisabled   <none>   67s   v1.29.3                  # we see this in minikube cluster
```

The `kubectl exec` and `kubectl logs` should work in the tenant control plane, as usual.

Let's try out `kubectl exec`:

```bash
$ VC_POD="$(kubectl get pod -l app='vc-test' --kubeconfig vc-1.kubeconfig -o jsonpath="{.items[0].metadata.name}")"
$ kubectl exec -it "${VC_POD}" --kubeconfig vc-1.kubeconfig -- /bin/sh

# We're now in the container
/ # ls
bin    dev    etc    home   lib    lib64  proc   root   run    sys    tmp    usr    var
```

And `kubectl logs` as well, yes we can see the logs from output of container's command `top`:

```bash
$ kubectl logs "${VC_POD}" --kubeconfig vc-1.kubeconfig
Mem: 3661816K used, 277772K free, 3136K shrd, 90344K buff, 2452572K cached
CPU:  4.0% usr  2.7% sys  0.0% nic 84.6% idle  0.1% io  0.0% irq  0.0% sirq
Load average: 0.59 0.59 0.49 1/489 3
  PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
```

## Clean Up



To delete only the created VirtualCluster
```bash
# The VirtualCluster
kubectl delete VirtualCluster vc-sample-1
```

To delete all the object created 

```bash
# The ClusterVersion
kubectl delete -f /home/ubuntu/capn-virtualcluster/cluster-api-provider-nested/virtualcluster/config/sampleswithspec/clusterversion_v1_nodeport_1-29.yaml

# The Virtual Cluster components
kubectl delete -f /home/ubuntu/capn-virtualcluster/cluster-api-provider-nested/virtualcluster/config/setup/all_in_one_ecr.yaml

# The ValidatingWebhookConfiguration which generated runtime and is cluster-scoped resource
kubectl delete ValidatingWebhookConfiguration virtualcluster-validating-webhook-configuration

# The CRDs
kubectl delete -f /home/ubuntu/capn-virtualcluster/cluster-api-provider-nested/virtualcluster/config/crd/tenancy.x-k8s.io_clusterversions.yaml
kubectl delete -f /home/ubuntu/capn-virtualcluster/cluster-api-provider-nested/virtualcluster/config/crd/tenancy.x-k8s.io_virtualclusters.yaml
```
