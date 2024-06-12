kubectl create ns vc-manager

kubectl create secret docker-registry awsecr --docker-server=580140558762.dkr.ecr.eu-north-1.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password) -n vc-manager
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-nested/main/virtualcluster/config/crd/tenancy.x-k8s.io_clusterversions.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-nested/main/virtualcluster/config/crd/tenancy.x-k8s.io_virtualclusters.yaml

kubectl create -f /home/ubuntu/cluster-bring-up/virtual-cluster/all_in_one_private_repo_no_namespace_creation.yaml


kubectl create -f clusterversion_v1_nodeport_sb_test.yaml

kubectl vc create -f /home/ubuntu/capn-virtualcluster/cluster-api-provider-nested/virtualcluster/config/sampleswithspec/virtualcluster_1_nodeport.yaml -o vc-1.kubeconfig
