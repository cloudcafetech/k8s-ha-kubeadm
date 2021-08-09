## Kubernetes Upgrade using Kubeadm

At first check your current kubeadm & kubectl version

In this example upgade done from 1.20.0 to 1.21.3-0

### 1st Master Node

- Step#1 Determine which version to upgrade

```yum list --showduplicates kubeadm --disableexcludes=kubernetes```

- Step#2 Upgrade kubeadm

```yum install -y kubeadm-1.21.3-0 --disableexcludes=kubernetes```

- Step#3 Verify version

```kubeadm version```

- Step#4 Verify the upgrade plan
kubeadm upgrade plan

- Step#5 Apply the upgrade plan

```kubeadm upgrade apply v1.21.3```

- Step#6 Update Kubelet and restart the service

```
yum install -y kubelet-1.21.3-0 kubectl-1.21.3-0 --disableexcludes=kubernetes
systemctl daemon-reload;systemctl restart kubelet
```

- Step#7 Uncordon the node (Bring the node back online by marking it schedulable)

```kubectl uncordon <Node which upgrade just now done>```

### 2nd Master & 3rd Master Node

Repeat Step#2, Step#3 

- Step#8 Drain the 2nd Master Node

```kubectl drain <2nd Master Node Name> --ignore-daemonsets```

- Step#9 Kubeadm upgrade

```kubeadm upgrade node```

- Step#10 Update Kubelet and restart the service

```
yum install -y kubelet-1.21.3-0 kubectl-1.21.3-0 --disableexcludes=kubernetes
systemctl daemon-reload;systemctl restart kubelet
```

- Step#11 Uncordon the 2nd Master node (Bring the node back online by marking it schedulable)

```kubectl uncordon <2nd Master Node Name>```

### 3rd Master Node

Repeat 

- Step#2 
- Step#3 

- Step#12 Drain the 3rd Master Node

```kubectl drain <3rd Master Node Name> --ignore-daemonsets```

Repeat 

- Step#8 
- Step#9

- Step#13 Uncordon the 3rd Master node (Bring the node back online by marking it schedulable)

```kubectl uncordon <3rd Master Node Name>```

## Upgrade worker nodes
Note: Do not upgrade the worker nodes parallel. Upgrade one node at a time

### 1st Worker Node

Repeat 

- Step#2 
- Step#3 

- Step#14 Drain the 1st Worker Node

```kubectl drain <1st Worker Node Name> --ignore-daemonsets```

Repeat 

- Step#8 
- Step#9

- Step#15 Uncordon the 1st Worker node (Bring the node back online by marking it schedulable)

```kubectl uncordon <1st Worker Node Name>```

### 2nd Worker Node

Repeat 

- Step#2 
- Step#3 

- Step#16 Drain the 2nd Worker Node

```kubectl drain <2nd Worker Node Name> --ignore-daemonsets```

Repeat 

- Step#8 
- Step#9

- Step#17 Uncordon the 2nd Worker node (Bring the node back online by marking it schedulable)

```kubectl uncordon <2nd Worker Node Name>```

### Contunue Same for Other Worker Nodes

## Finally, verify the status of the cluster

```kubectl get nodes```
