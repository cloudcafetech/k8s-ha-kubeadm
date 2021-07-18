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

- Edit & update IP details of Masters,Nodes & Load Balancer, make executable & Run 

```
vi haproxy-lb-setup.sh
chmod 755 haproxy-lb-setup.sh
./haproxy-lb-setup.sh

vi k8s-setup.sh
chmod 755 k8s-setup.sh
./k8s-setup.sh
```

- Post Setup

```
```
