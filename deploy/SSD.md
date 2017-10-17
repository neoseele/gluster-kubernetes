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
--local-ssd-count=1 \
--scopes cloud-platform,storage-rw,logging-write,monitoring-write,service-control,service-management
```

### Modprobe / Cleanup SSD

```sh
i=1
for node in `kubectl get nodes -o jsonpath='{.items[*].metadata.name}'`;
do
  echo "* ${node}";
  gcloud compute ssh $node --zone us-central1-b -- 'sudo sh -c "modprobe dm_thin_pool; modprobe dm_snapshot; modprobe dm_mirror"'
  gcloud compute ssh $node --zone us-central1-b -- 'sudo sh -c "umount /dev/sdb && dd if=/dev/zero of=/dev/sdb bs=512 count=100"'
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
ADMIN_KEY='12qwaszx34erdfcv'
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
echo $HEKETI
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

## Clean Up

* Delete load balancer type services
```sh
kubectl get service
```

* Delete the cluster
```sh
gcloud container clusters delete kube-test --zone us-central1-b
```
