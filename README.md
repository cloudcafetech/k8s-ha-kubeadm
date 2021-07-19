# Kubernetes HA Setup
Kubernetes HA setup using Kubeadm

### K8S Architecture
<p align="center">
  <img src="https://github.com/cloudcafetech/k8s-ha-kubeadm/blob/main/arc.png">
</p>

### Port Open
<p align="center">
  <img src="https://github.com/cloudcafetech/k8s-ha-kubeadm/blob/main/ports.png">
</p>

### Setup

- Download 

```
wget https://raw.githubusercontent.com/cloudcafetech/k8s-ha-kubeadm/main/haproxy-lb-setup.sh
wget https://raw.githubusercontent.com/cloudcafetech/k8s-ha-kubeadm/main/k8s-setup.sh
```

- HAPROXY (Edit & update IP details of Masters, make executable & Run)

```
vi haproxy-lb-setup.sh
chmod 755 haproxy-lb-setup.sh
./haproxy-lb-setup.sh
```

- Add PEM Key & change mode

```
vi key.pem
chmod 400 key.pem
```

- K8S (Edit & update IP details of Masters,Nodes & Load Balancer, make executable & Run)

```
vi k8s-setup.sh
chmod 755 k8s-setup.sh
./k8s-setup.sh
```

### Post Setup

- Setup Ingress

```
wget https://raw.githubusercontent.com/cloudcafetech/k8s-ha-kubeadm/main/kube-ingress.yaml
kubectl create ns kube-router
kubectl create -f kube-ingress.yaml
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission
```

- Setup Demo Application

```
wget https://raw.githubusercontent.com/cloudcafetech/k8s-ha-kubeadm/main/sample-app.yaml
kubectl create ns demo-mongo
kubectl create -f sample-app.yaml -n demo-mongo
```
