## Configure Load Balancing

Keepalived provides a VRPP implementation and allows you to configure Linux machines for load balancing, preventing single points of failure. HAProxy, providing reliable, high performance load balancing, works perfectly with Keepalived.

As Keepalived and HAproxy are installed on lb1 and lb2, if either one goes down, the virtual IP address (i.e. the floating IP address) will be automatically associated with another node so that the cluster is still functioning well, thus achieving high availability. If you want, you can add more nodes all with Keepalived and HAproxy installed for that purpose.

### HAproxy

#### Install Keepalived and HAproxy

```yum install keepalived haproxy psmisc -y```

#### Create configuration of HAproxy

```
>/etc/haproxy/haproxy.cfg
cat > /etc/haproxy/haproxy.cfg << EOF
frontend kube-apiserver
   bind 0.0.0.0:6443
   mode tcp
   option tcplog
   #default_backend prod-apiserver
   #default_backend test-apiserver
   acl prod src 172.31.27.4
   acl test src 172.31.16.10
   use_backend prod-apiserver if prod
   use_backend test-apiserver if test

backend prod-apiserver
    mode tcp
    option tcplog
    option tcp-check
    balance roundrobin
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
    server ip-172-31-24-38.us-east-2.compute.internal 172.31.24.38:6443 check

backend test-apiserver
    mode tcp
    option tcplog
    option tcp-check
    balance roundrobin
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
    server ip-172-31-17-153.us-east-2.compute.internal 172.31.17.153:6443 check
EOF
```

#### Restart HAproxy & make it persist through reboots

```systemctl restart haproxy; systemctl enable haproxy```

### Keepalived

#### Configure Keepalived

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
    virtual_router_id 101
    priority 101
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        172.31.27.4
    }
    track_script {
        prod-apiserver
    }

vrrp_instance VI_2 {
    state MASTER
    interface eth0
    virtual_router_id 102
    priority 102
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        172.31.16.10
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
