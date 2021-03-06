## Configure Load Balancing

Keepalived provides a VRPP implementation and allows you to configure Linux machines for load balancing, preventing single points of failure. HAProxy, providing reliable, high performance load balancing, works perfectly with Keepalived.

As Keepalived and HAproxy are installed on lb1 and lb2, if either one goes down, the virtual IP address (i.e. the floating IP address) will be automatically associated with another node so that the cluster is still functioning well, thus achieving high availability. If you want, you can add more nodes all with Keepalived and HAproxy installed for that purpose.

### HAproxy

#### Install Keepalived and HAproxy

```
yum install keepalived haproxy psmisc nmap telnet git -y
if ! command -v kubectl &> /dev/null;
then
 echo "Installing Kubectl"
 K8S_VER=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
 wget -q https://storage.googleapis.com/kubernetes-release/release/$K8S_VER/bin/linux/amd64/kubectl
 chmod +x ./kubectl; mv ./kubectl /usr/bin/kubectl
 echo "alias oc=/usr/bin/kubectl" >> /root/.bash_profile
fi 
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
set -x; cd "$(mktemp -d)" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.{tar.gz,yaml}" &&
  tar zxvf krew.tar.gz &&
  KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" &&
  "$KREW" install --manifest=krew.yaml --archive=krew.tar.gz &&
  "$KREW" update

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

kubectl krew install modify-secret
kubectl krew install ctx
kubectl krew install ns
kubectl krew install cost

echo 'export PATH="${PATH}:${HOME}/.krew/bin"' >> /root/.bash_profile
exit
```

#### Create configuration of HAproxy

```
>/etc/haproxy/haproxy.cfg
cat > /etc/haproxy/haproxy.cfg << EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 1
    timeout http-request    10s
    timeout queue           20s
    timeout connect         5s
    timeout client          20s
    timeout server          20s
    timeout http-keep-alive 10s
    timeout check           10s

frontend kube-apiserver
   bind 0.0.0.0:6443
   mode tcp
   option tcplog
   default_backend prod-apiserver
   #default_backend test-apiserver
   #acl prod src ip-172-31-23-216.us-east-2.compute.internal
   #acl test src ip-172-31-16-10.us-east-2.compute.internal
   #use_backend prod-apiserver if prod
   #use_backend test-apiserver if test

backend prod-apiserver
    option httpchk GET /healthz
    http-check expect status 200
    mode tcp
    option ssl-hello-chk
    balance roundrobin
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
    server ip-172-31-30-82.us-east-2.compute.internal 172.31.30.82:6443 check

backend test-apiserver
    option httpchk GET /healthz
    http-check expect status 200
    mode tcp
    option ssl-hello-chk
    balance roundrobin
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
    server ip-172-31-25-88.us-east-2.compute.internal 172.31.25.88:6443 check
EOF
```

#### Restart HAproxy & make it persist through reboots

```systemctl restart haproxy; systemctl enable haproxy; systemctl status haproxy```

### Keepalived

#### Configure Keepalived for Primary server (MASTER)

```
>/etc/keepalived/keepalived.conf
cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
    router_id LVS_DEVEL
}

vrrp_script prod-apiserver {
  script "/etc/keepalived/prod-apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_script test-apiserver {
  script "/etc/keepalived/test-apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    unicast_src_ip 172.31.16.11    # The IP address of this machine (MASTER)
    unicast_peer {
        172.31.16.12               # The IP address of peer machines (BACKUP)    
    virtual_router_id 101
    priority 101
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        172.31.27.4                # The VIP address
    }
    track_script {
        prod-apiserver
    }

vrrp_instance VI_2 {
    state MASTER
    interface eth0
    unicast_src_ip 172.31.16.11    # The IP address of this machine (MASTER)
    unicast_peer {
        172.31.16.12               # The IP address of peer machines (BACKUP)
    }    
    virtual_router_id 102
    priority 101
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        172.31.16.10               # The VIP address
    }
    track_script {
        test-apiserver
    }

}
EOF
```

#### Configure Keepalived for Peer server (BACKUP)

```
>/etc/keepalived/keepalived.conf
cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
    router_id LVS_DEVEL
}

vrrp_script prod-apiserver {
  script "/etc/keepalived/prod-apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_script test-apiserver {
  script "/etc/keepalived/test-apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    unicast_src_ip 172.31.16.12    # The IP address of this machine (BACKUP)
    unicast_peer {
        172.31.16.11               # The IP address of peer machines (MASTER)    
    virtual_router_id 101
    priority 100
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        172.31.27.4                # The VIP address
    }
    track_script {
        prod-apiserver
    }

vrrp_instance VI_2 {
    state BACKUP
    interface eth0
    unicast_src_ip 172.31.16.12    # The IP address of this machine (BACKUP)
    unicast_peer {
        172.31.16.11               # The IP address of peer machines (MASTER)
    }    
    virtual_router_id 102
    priority 100
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        172.31.16.10               # The VIP address
    }
    track_script {
        test-apiserver
    }

}
EOF
```

#### Create Keepalive Script for multiple apiserver

```
cat > /etc/keepalived/prod-apiserver.sh << EOF
#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl --silent --max-time 2 --insecure https://localhost:6443/ -o /dev/null || errorExit "Error GET https://localhost:6443/"
if ip addr | grep -q 172.31.27.4; then
    curl --silent --max-time 2 --insecure https://172.31.27.4:6443/ -o /dev/null || errorExit "Error GET https://172.31.27.4:6443/"
fi
EOF

cat > /etc/keepalived/test-apiserver.sh << EOF
#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl --silent --max-time 2 --insecure https://localhost:6443/ -o /dev/null || errorExit "Error GET https://localhost:6443/"
if ip addr | grep -q 172.31.16.10; then
    curl --silent --max-time 2 --insecure https://172.31.16.10:6443/ -o /dev/null || errorExit "Error GET https://172.31.16.10:6443/"
fi
EOF

chmod +x /etc/keepalived/*.sh
systemctl restart keepalived
```

#### Check Ststus

```systemctl status haproxy; systemctl status keepalived```

[Ref #1](https://kubesphere.io/docs/installing-on-linux/high-availability-configurations/set-up-ha-cluster-using-keepalived-haproxy/)

[Ref #2](https://metal.equinix.com/developers/guides/load-balancing-ha/)

[Ref #3](https://github.com/kubernetes/kubeadm/blob/master/docs/ha-considerations.md)
