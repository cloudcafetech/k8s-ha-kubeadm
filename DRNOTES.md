## Disaster Simulation


### Initiate Kubernetes

```
curl -o k8s-host-setup.sh https://raw.githubusercontent.com/cloudcafetech/k8s-ha-kubeadm/main/k8s-host-setup.sh
chmod +x k8s-host-setup.sh
./k8s-host-setup.sh
kubeadm init --ignore-preflight-errors=all 
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

### Make master to POD schedule

```
MASTER=`kubectl get nodes | grep master | awk '{print $1}'`
kubectl taint nodes $MASTER node-role.kubernetes.io/master-
kubectl get nodes -o json | jq .items[].spec.taints
```

### Running Minio

```
docker run -d -p 9000:9000 --restart=always --name minio \
  -e "MINIO_ACCESS_KEY=admin" \
  -e "MINIO_SECRET_KEY=admin2675" \
  -v /root/minio/data:/data \
  -v /root/minio/config:/root/.minio \
  minio/minio server /data
  ```
  
### Backup ETCD 

Update Minio Server IP & Port

```kubectl create -f etcd-backup-job.yaml```

### Similate Disaster

Make sure etcd backup done ...

```rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet; docker kill `docker ps -a | grep -v minio | awk '{print $1'} | grep -v CONTAINER`; docker rm `docker ps -a | grep -v minio | awk '{print $1'} | grep -v CONTAINER`;systemctl stop docker;systemctl stop kubelet;umount $(df -HT | grep '/var/lib/kubelet/pods' | awk '{print $7}')```


### Restore ETCD

Update Minio Server IP & Port

```./etcd-restore.sh```

#### Setup Minio Client Tool

```
MinIO=172.31.21.248
wget https://dl.min.io/client/mc/release/linux-amd64/mc; chmod +x mc; mv -v mc /usr/local/bin/mc
mc config host add minio http://$MinIO:9000 admin admin2675 --insecure
mc mb minio/prodetcd --insecure
```

#### Flannel issue ```configured flannel before running kubeadm init```

rm -f /etc/cni/net.d/*flannel*

#### kubelet unmount pod, error ```device or resource busy```

```umount $(df -HT | grep '/var/lib/kubelet/pods' | awk '{print $7}')```

