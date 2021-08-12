#!/usr/bin/env bash
# Kubernetes host setup script for Linux (CentOS,RHEL,Amazon)

K8S_VER=1.20.0

# Install some of the tools (including CRI-O, kubeadm & kubelet) we’ll need on our servers.
echo 'WrM9#RPtaXut' | sudo -S yum install -y git curl wget bind-utils jq httpd-tools zip unzip nfs-utils go nmap telnet tc dos2unix java-1.7.0-openjdk

# Install Docker
if ! command -v docker &> /dev/null;
then
  echo "MISSING REQUIREMENT: docker engine could not be found on your system. Please install docker engine to continue: https://docs.docker.com/get-docker/"
  echo "Trying to Install Docker..."
  if [[ $(uname -a | grep amzn) ]]; then
    echo "Installing Docker for Amazon Linux"
    echo 'WrM9#RPtaXut' | sudo -S amazon-linux-extras install docker -y
  else
    #echo 'WrM9#RPtaXut' | sudo -S curl -s https://releases.rancher.com/install-docker/19.03.sh | sh
    echo 'WrM9#RPtaXut' | sudo -S curl -s https://releases.rancher.com/install-docker/20.10.sh | sh    
  fi    
fi

echo 'WrM9#RPtaXut' | sudo -S systemctl start docker; echo 'WrM9#RPtaXut' | sudo -S systemctl status docker; echo 'WrM9#RPtaXut' | sudo -S systemctl enable docker

# Stopping and disabling firewalld by running the commands on all servers:
echo 'WrM9#RPtaXut' | sudo -S systemctl stop firewalld
echo 'WrM9#RPtaXut' | sudo -S systemctl disable firewalld

# Disable swap. Kubeadm will check to make sure that swap is disabled when we run it, so lets turn swap off and disable it for future reboots.
echo 'WrM9#RPtaXut' | sudo -S swapoff -a
echo 'WrM9#RPtaXut' | sudo -S sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

# Disable SELinux
echo 'WrM9#RPtaXut' | sudo -S setenforce 0
echo 'WrM9#RPtaXut' | sudo -S sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

# Add the kubernetes repository to yum so that we can use our package manager to install the latest version of kubernetes. 
echo 'WrM9#RPtaXut' | sudo -S cat <<EOF | echo 'WrM9#RPtaXut' | sudo -S tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# Change default cgroup driver to systemd 
echo 'WrM9#RPtaXut' | sudo -S cat > daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

echo 'WrM9#RPtaXut' | sudo -S cp daemon.json /etc/docker/daemon.json
echo 'WrM9#RPtaXut' | sudo -S systemctl start docker; echo 'WrM9#RPtaXut' | sudo -S systemctl status docker; echo 'WrM9#RPtaXut' | sudo -S systemctl enable docker

echo 'WrM9#RPtaXut' | sudo -S cat <<EOF > k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

echo 'WrM9#RPtaXut' | sudo -S cp k8s.conf /etc/sysctl.d/k8s.conf
echo 'WrM9#RPtaXut' | sudo -S sysctl --system
echo 'WrM9#RPtaXut' | sudo -S systemctl restart docker
echo 'WrM9#RPtaXut' | sudo -S systemctl status docker

# Installation with specefic version
if [[ "$K8S_VER" == "" ]]; then
 echo 'WrM9#RPtaXut' | sudo -S yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
else
 echo 'WrM9#RPtaXut' | sudo -S yum install -y kubelet-$K8S_VER kubeadm-$K8S_VER kubectl-$K8S_VER --disableexcludes=kubernetes
fi

# After installing container runtime and our kubernetes tools
# we’ll need to enable the services so that they persist across reboots, and start the services so we can use them right away.
echo 'WrM9#RPtaXut' | sudo -S systemctl enable --now kubelet; echo 'WrM9#RPtaXut' | sudo -S systemctl start kubelet; echo 'WrM9#RPtaXut' | sudo -S systemctl status kubelet
