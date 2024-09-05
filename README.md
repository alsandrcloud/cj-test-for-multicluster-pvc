# cj-test-for-multicluster-pvc

This is basic configuration to demo: 
"“Design active-passive Kubernetes clusters where stateful applications that write to the file system can recover their data upon failover. How would you accomplish this in AWS?”" 

To accomplish the task we'd need 
1) Create an EFS file system and and create mount targets in each subnet. To simplify the task we will reuse existing default vpc and not create new one
2) Add security Security group for EFS allowing NFS access
3) Add the two eks clusters 
To simplify it we'll be using terraform which should manage all the resources (it's assumed that the aws credentials configured on the host where the repo is cloned):
Steps: 
Inside of the main directory of the repo run 
```
terraform init 
```
then 
```
terraform plan 
```
if there are no errors we can apply the configuration from the eks.tf
```
terraform apply --auto-approve
```

It may take some time to deploy the clusters and node groups

Once it's complete you can configure your access to the clusters and the apply persistentVolume, persistentVolumeClaim and the test statefulSet to validate that the mounts are working as expected. 
add the k8s configs from the new clusters
```
aws eks update-kubeconfig --name cj-test-one
aws eks update-kubeconfig --name cj-test-two
```


Since the efs-csi-driver not installed by default you may need install it 
```
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo update aws-efs-csi-driver
helm upgrade --install aws-efs-csi-driver --namespace kube-system aws-efs-csi-driver/aws-efs-csi-driver
Release "aws-efs-csi-driver" has been upgraded. Happy Helming!
NAME: aws-efs-csi-driver
LAST DEPLOYED: Thu Sep  5 16:04:50 2024
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
To verify that aws-efs-csi-driver has started, run:

    kubectl get pod -n kube-system -l "app.kubernetes.io/name=aws-efs-csi-driver,app.kubernetes.io/instance=aws-efs-csi-driver"
```

Once it's installed you can proceed with the PV, PVC and the StatefulSet
```
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml
```

you can check if the pvc bound successfully:
```
kubectl get pvc 
NAME      STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
efs-pvc   Bound    efs-pv   5Gi        RWX                           <unset>                 1m
```

Finally apply your statefulset 
```
kubectl apply -f statefulset.yaml
```
You need perform the installations in both clusters

Once complete you can validate that all the pods from both clusters use the same volume. 
Run
```
kubectl exec -it cjtest-0 -- cat /mnt/data/output.txt
....
cjtest-0 -  addr:172.31.32.251 - Thu Sep  5 23:10:55 UTC 2024
cjtest-2 -  addr:172.31.46.40 - Thu Sep  5 23:10:55 UTC 2024
cjtest-1 -  addr:172.31.3.101 - Thu Sep  5 23:10:57 UTC 2024
cjtest-2 -  addr:172.31.46.199 - Thu Sep  5 23:10:59 UTC 2024
cjtest-0 -  addr:172.31.37.231 - Thu Sep  5 23:11:00 UTC 2024
cjtest-1 -  addr:172.31.21.43 - Thu Sep  5 23:11:03 UTC 2024
cjtest-0 -  addr:172.31.32.251 - Thu Sep  5 23:11:05 UTC 2024
cjtest-2 -  addr:172.31.46.40 - Thu Sep  5 23:11:05 UTC 2024
cjtest-1 -  addr:172.31.3.101 - Thu Sep  5 23:11:07 UTC 2024
cjtest-2 -  addr:172.31.46.199 - Thu Sep  5 23:11:09 UTC 2024
cjtest-0 -  addr:172.31.37.231 - Thu Sep  5 23:11:10 UTC 2024
cjtest-1 -  addr:172.31.21.43 - Thu Sep  5 23:11:13 UTC 2024
cjtest-0 -  addr:172.31.32.251 - Thu Sep  5 23:11:15 UTC 2024
cjtest-2 -  addr:172.31.46.40 - Thu Sep  5 23:11:15 UTC 2024
```
the output should have 6 different ips from 6 pods/containers in two different custers