## Deploy Gluster

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

### Attach disk / modprobe

```sh
i=1
for node in `kubectl get nodes -o jsonpath='{.items[*].metadata.name}'`;
do
  echo "* ${node}";
  gcloud compute ssh $node --zone us-central1-b -- sudo modprobe dm_thin_pool;
  gcloud compute ssh $node --zone us-central1-b -- sudo modprobe dm_snapshot;
  gcloud compute ssh $node --zone us-central1-b -- sudo modprobe dm_mirror;
  gcloud compute instances attach-disk $node --disk gluster-data-${i} --zone us-central1-b;
  ((i+=1))
done
```

### Recreate topology.json

```sh
cd deploy
```

```sh
ruby build_topology.rb <( gcloud compute instances list | grep kube-test | tr -s ' ' ) > topology.json
```
* _Internal IP used in topology.json_

### Deploy

```sh
ADMIN_KEY='12qwaszx!@'
USER_KEY='12qwaszx'

./gk-deploy -g --admin-key $ADMIN_KEY --user-key $USER_KEY --no-object
```

### Create admin secret (optional)
```sh
kubectl create secret generic heketi-admin-secret \
  --from-literal=key=$ADMIN_KEY \
  --type=kubernetes.io/glusterfs
```

### Create storage class

```sh
HEKETI="$(kubectl describe service heketi | grep Ingress: | awk '{print $3}'):8080"
```
(use the heketi service IP for resturl)

```sh
cat << EOF | kubectl apply -f -
---
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: gluster-heketi
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://${HEKETI}"
  restuser: "admin"
  # restuserkey: "${ADMIN_KEY}"
  secretNamespace: "default"
  secretName: "heketi-admin-secret"
EOF
```

### Setup Heketi Cli

```sh
export HEKETI_CLI_SERVER=http://$HEKETI
```

```sh
heketi-cli --user admin --secret $ADMIN_KEY volume list
```


## Increase Cluster Size

### Add node

```sh
gcloud container clusters resize kube-test --size 4 --zone us-central1-b
```

### Create disk

```sh
gcloud compute disks create --size 100GB --zone us-central1-b gluster-data-4
```

### Attach disk / modprobe

```sh
node=<NEW_NODE>
gcloud compute ssh $node --zone us-central1-b -- sudo modprobe dm_thin_pool;
gcloud compute ssh $node --zone us-central1-b -- sudo modprobe dm_snapshot;
gcloud compute ssh $node --zone us-central1-b -- sudo modprobe dm_mirror;
gcloud compute instances attach-disk $node --disk gluster-data-4 --zone us-central1-b;
```

### Recreate topology.json

```sh
ruby build_topology.rb <( gcloud compute instances list | grep kube-test | tr -s ' ' ) > topology.json
```

### Reload topology.json

```sh
heketi-cli --user admin --secret $ADMIN_KEY topology load --json=topology.json
```

## Clean Up

* Delete load balancer type services
```sh
kubectl get service
```

* Delete the cluster
```sh
gcloud container clusters delete kube-test --zone us-central1-b
```

* Delete the PDs
```sh
gcloud compute disks delete --zone us-central1-b gluster-data-1
gcloud compute disks delete --zone us-central1-b gluster-data-2
gcloud compute disks delete --zone us-central1-b gluster-data-3
gcloud compute disks delete --zone us-central1-b gluster-data-4
```
