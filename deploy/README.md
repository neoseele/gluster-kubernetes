### Create the GKE cluster

_must have minimal 3 nodes to run a gluster cluster_

```sh
gcloud beta container clusters create kube-test \
--zone=us-central1-b \
--machine-type=n1-standard-2 \
--num-nodes=3 \
--image-type=UBUNTU \
--node-labels=storagenode=glusterfs \
--tags=ssh \
--scopes cloud-platform,storage-rw,logging-write,monitoring-write,service-control,service-management
```

### Create disks

- create 3 persistent disks
- add them to the nodes (one each)

```sh
gcloud compute disks create --size 100GB --zone us-central1-b gluster-data-1
gcloud compute disks create --size 100GB --zone us-central1-b gluster-data-2
gcloud compute disks create --size 100GB --zone us-central1-b gluster-data-3
```

### modprobe

```sh
for node in `kubectl get nodes | egrep '^gke' | awk '{print $1}'`;
do
  echo "> ${node}";
  gcloud compute ssh $node --zone us-central1-b -- sudo modprobe dm_thin_pool;
  gcloud compute ssh $node --zone us-central1-b -- sudo modprobe dm_snapshot;
  gcloud compute ssh $node --zone us-central1-b -- sudo modprobe dm_mirror;
done
```

### Deploy gluster

(https://github.com/gluster/gluster-kubernetes.git)

```sh
ADMIN_KEY='12qwaszx!@'
USER_KEY='12qwaszx'

./gk_deploy -g --admin-key $ADMIN_KEY --user-key $USER_KEY --no-object
```

### Create admin secret
```sh
kubectl create secret generic heketi-admin-secret \
  --from-literal=key=$ADMIN_KEY \
  --type=kubernetes.io/glusterfs
```

### Create storage class

```sh
HEKETI=$(kubectl describe service heketi | grep Ingress | awk '{print $2}')
```
(use the heketi service IP for resturl)

```sh
echo "
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: gluster-heketi
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://${HEKETI}"
  restuser: "admin"
  restuserkey: ""
" | kubectl apply -f -
```

[1] https://github.com/gluster/gluster-kubernetes/blob/master/docs/setup-guide.md
[2] http://blog.lwolf.org/post/how-i-deployed-glusterfs-cluster-to-kubernetes/
