#!/usr/bin/env bash
# Controlpane & node joining script
# Note: If certificate-key expire, generate new using (kubeadm init phase upload-certs --upload-certs)

ADDMASTER1=172.31.21.8
ADDNODE1=172.31.22.99

HA_PROXY_LB_DNS=172.31.28.212
HA_PROXY_LB_PORT=6443
MASTER1_IP=172.31.17.140

USER=ec2-user
PEMKEY=key.pem

# Validating
master=$1
if [[ ! $master =~ ^( |master|node)$ ]]; then 
 echo "Usage: host-setup.sh <master or node>"
 echo "Example: host-setup.sh master/node"
 exit
fi

# Checking Load Balancer Response
LBTEST=`nc -w 2 -v $HA_PROXY_LB_DNS $HA_PROXY_LB_PORT </dev/null; echo $?`
if [[ "$LBTEST" == "0" ]]; then
  echo "OK - Load Balancer ($HA_PROXY_LB_DNS) on port ($HA_PROXY_LB_PORT) responding."
else 
  echo "NOT Good - Load Balancer ($HA_PROXY_LB_DNS) on port ($HA_PROXY_LB_PORT) NOT responding."
  echo "Please Check Load Balancer ($HA_PROXY_LB_DNS) on port ($HA_PROXY_LB_PORT), before proceeding."
  exit
fi

# Checking All Deployment Hosts Response
for rip in $MASTER1_IP $ADDMASTER1 $ADDNODE1
do
HTEST=`nc -w 2 -v $rip 22 </dev/null; echo $?`
if [[ "$HTEST" == "1" ]]; then
  echo "NOT Good - Host ($rip) on ssh port (22) NOT responding."
  echo "Please Check Host ($rip) on ssh port (22), before proceeding."
  exit  
else 
  echo "OK - Host ($rip) on ssh port (22) responding."
fi
done

# New Host Preparation
for hip in $ADDMASTER1 $ADDNODE1
do
echo "K8S Host Preparation on $hip"
ssh $USER@$hip -o 'StrictHostKeyChecking no' -i $PEMKEY "curl -o k8s-host-setup.sh https://raw.githubusercontent.com/cloudcafetech/k8s-ha-kubeadm/main/k8s-host-setup.sh"
ssh $USER@$hip -o 'StrictHostKeyChecking no' -i $PEMKEY "chmod +x /home/$USER/k8s-host-setup.sh"
ssh $USER@$hip -o 'StrictHostKeyChecking no' -i $PEMKEY "/home/$USER/k8s-host-setup.sh"
done

# Getting Details from Master#1
TOKEN=$(ssh $USER@$MASTER1_IP -o 'StrictHostKeyChecking no' -i $PEMKEY "sudo kubeadm token generate")
OUTPUT=$(ssh $USER@$MASTER1_IP -o 'StrictHostKeyChecking no' -i $PEMKEY "sudo kubeadm init phase upload-certs --upload-certs")
CERTKEY=$(echo $OUTPUT | cut -d ":" -f2 | cut -d " " -f2)
tokenSHA=$(ssh $USER@$MASTER1_IP -o 'StrictHostKeyChecking no' -i $PEMKEY "sudo openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -pubkey | sudo openssl rsa -pubin -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1")
joinMaster="sudo kubeadm join $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --token=$TOKEN --control-plane --certificate-key=$CERTKEY --discovery-token-ca-cert-hash sha256:$tokenSHA --ignore-preflight-errors=all"
joinNode="sudo kubeadm join $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --token=$TOKEN --discovery-token-ca-cert-hash sha256:$tokenSHA --ignore-preflight-errors=all"

# Adding Masters
if [[ "$master" == "master" ]]; then
 for mip in $ADDMASTER1
 do
  echo "Joining Masters ($mip)"
  ssh $USER@$mip-o 'StrictHostKeyChecking no' -i $PEMKEY $joinMaster
  exit
 done
fi

# Adding Nodes
if [[ "$master" == "node" ]]; then
 for nip in $ADDNODE1
 do
  echo "Joining Nodes ($nip)"
  ssh $USER@$nip -o 'StrictHostKeyChecking no' -i $PEMKEY $joinNode
  exit
 done
fi
