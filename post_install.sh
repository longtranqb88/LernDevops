### Mô hình hệ thống: Tham khải Tài liệu triển khai k8s với kubespray
## Cài đặt máy chủ Ansible,HA Proxy, Rancher, Git Node
#!/bin/bash
#### Disable firewalld, selinux and install python3 for Ansible
systemctl stop firewalld && systemctl disable firewalld
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
yum update -y
yum  groupinstall "Development Tools" -y ; yum install curl wget psmisc net-tools git vim openssl-devel sshpass bzip2-devel libffi-devel xz-devel haproxy keepalived -y
cd /opt && wget https://www.python.org/ftp/python/3.8.12/Python-3.8.12.tgz
tar xvf Python-3.8.12.tgz && cd Python-3.8*/
./configure --enable-optimizations &&  make altinstall && pip3.8 install --upgrade pip && ln -s /usr/local/bin/python3.8 /usr/bin/python3
###====#
iface_name=$(ip route get 8.8.8.8 | sed -nr 's/.*dev ([^\ ]+).*/\1/p')
vip_ip=$(cat /opt/.value.txt | grep 'VIP_ADDRESS')
master_host01=$(cat /opt/.value.txt | grep -w "HMASTER01" | cut -d "=" -f2)
master_host02=$(cat /opt/.value.txt | grep -w "HMASTER02" | cut -d "=" -f2)
master_host03=$(cat /opt/.value.txt | grep -w "HMASTER03" | cut -d "=" -f2)
master_ip01=$(cat /opt/.value.txt | grep -w "MASTER01_IP" | cut -d "=" -f2)
master_ip02=$(cat /opt/.value.txt | grep -w "MASTER02_IP" | cut -d "=" -f2)
master_ip03=$(cat /opt/.value.txt | grep -w "MASTER03_IP"| cut -d "=" -f2)
worker_host01=$(cat /opt/.value.txt | grep -w "HWORKER01" | cut -d "=" -f2)
worker_host02=$(cat /opt/.value.txt | grep -w "HWORKER02" | cut -d "=" -f2)
worker_host03=$(cat /opt/.value.txt | grep -w "HWORKER03" | cut -d "=" -f2)
worker_ip01=$(cat /opt/.value.txt | grep -w "WORKER01_IP" | cut -d "=" -f2)
worker_ip02=$(cat /opt/.value.txt | grep -w "WORKER02_IP" | cut -d "=" -f2)
worker_ip03=$(cat /opt/.value.txt | grep -w "WORKER03_IP" | cut -d "=" -f2)
haproxy_user=$(cat /opt/.value.txt | grep -w "haproxy_u" | cut -d "=" -f2)
haproxy_pass=$(cat /opt/.value.txt | grep -w "haproxy_p" | cut -d "=" -f2)
domain_name=$(cat /opt/.value.txt | grep -w "DOMAIN_NAME" | cut -d "=" -f2)
### External Load Balancing
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.origin
cat <<EOF >> /etc/haproxy/haproxy.cfg
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon
    stats socket /var/lib/haproxy/stats

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         30s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 30s
    timeout check           30s
    maxconn                 5000

frontend kubernetes-apiserver
    bind *:6443
    option tcplog
    mode tcp
    default_backend kubernetes-backend

# Control-Plane kubernetes node and routing rules
backend kubernetes-backend
    mode tcp
    balance roundrobin
    option tcp-check
    server $master_host01 $master_ip01:6443 check fall 2 rise 1
    server $master_host02 $master_ip02:6443 check fall 2 rise 1
    server $master_host03 $master_ip03:6443 check fall 2 rise 1

# Monitor Haproxy traffics
listen stat
    bind *:2023
    mode http
    stats enable
    stats uri /kubernetes-traffics
    stats realm HAProxy\ Statistics \ Kubernetes
    stats auth $haproxy_user:$haproxy_pass
EOF
tr -d '\r' < /etc/haproxy/haproxy.cfg > /etc/haproxy/haproxy.cfg.new && mv /etc/haproxy/haproxy.cfg.new /etc/haproxy/haproxy.cfg
mv /etc/keepalived/keepalived.conf  /etc/keepalived/keepalived.conf.origin
cat <<EOF >> /etc/keepalived/keepalived.conf
! Configuration File for keepalived

vrrp_script api-check {
    script "killall -0 haproxy"
    interval 5
    weight 10
}

global_defs {
   notification_email {
   }
   router_id LVS_DEVEL
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
}

vrrp_instance haproxy {
    state MASTER
    interface $iface_name
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass svtech
    }
    virtual_ipaddress {
        $vip_ip
    }
    track_script {
        api-check
    }
}
EOF
tr -d '\r' < /etc/keepalived/keepalived.conf > /etc/keepalived/keepalived.conf.new && mv /etc/keepalived/keepalived.conf.new /etc/keepalived/keepalived.conf
systemctl start keepalived ; systemctl enable keepalived
systemctl start haproxy ; systemctl enable haproxy 
cd ~/ ; git clone https://github.com/kubernetes-sigs/kubespray.git --branch release-2.21
ANSIBLE_VERSION=2.12 && cd kubespray && pip install -U -r requirements-$ANSIBLE_VERSION.txt
cp -rfp inventory/sample inventory/mycluster
cat <<EOF >> ./inventory/mycluster/group_vars/hosts.yml
all:
  hosts:
    $master_host01:
      ansible_host: $master_ip01
      ip: $master_ip01
      access_ip: $master_ip01
    $master_host02:
      ansible_host: $master_ip02
      ip: $master_ip02
      access_ip: $master_ip02
    $master_host03:
      ansible_host: $master_ip03
      ip: $master_ip03
      access_ip: $master_ip03
    $worker_host01:
      ansible_host: $worker_ip01
      ip: $worker_ip01
      access_ip: $worker_ip01
    $worker_host02:
      ansible_host: $worker_ip02
      ip: $worker_ip02
      access_ip: $worker_ip02
    $worker_host03:
      ansible_host: $worker_ip03
      ip: $worker_ip03
      access_ip: $worker_ip03
  children:
    kube_control_plane:
      hosts:
        $master_host01:
        $master_host02:
        $master_host03:
    kube_node:
      hosts:
        $worker_host01:
        $worker_host02:
        $worker_host03:
    etcd:
      hosts:
        $master_host01:
        $master_host02:
        $master_host03:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
EOF
tr -d '\r' < ./inventory/mycluster/group_vars/hosts.yml > ./inventory/mycluster/group_vars/hosts.yml.new && mv ./inventory/mycluster/group_vars/hosts.yml.new ./inventory/mycluster/group_vars/hosts.yml
# Custome file all.yml 
sed -i 's/## apiserver_loadbalancer_domain_name: "elb.some.domain"/apiserver_loadbalancer_domain_name: '"lb-$domain_name"'/g' ~/kubespray/inventory/mycluster/group_vars/all/all.yml
sed -i 's/# loadbalancer_apiserver_localhost: true/# loadbalancer_apiserver_localhost: false/g' ~/kubespray/inventory/mycluster/group_vars/all/all.yml
sed -i 's/# loadbalancer_apiserver_localhost: true/# loadbalancer_apiserver_localhost: false/g' ~/kubespray/inventory/mycluster/group_vars/all/all.yml
sed -i 's/# upstream_dns_servers:/upstream_dns_servers:/g' ~/kubespray/inventory/mycluster/group_vars/all/all.yml
sed -i 's/#   - 8.8.8.8/  - 8.8.8.8/g' ~/kubespray/inventory/mycluster/group_vars/all/all.yml
sed -i 's/ntp_enabled: false/ntp_enabled: true/g' ~/kubespray/inventory/mycluster/group_vars/all/all.yml
sed -i 's/ntp_manage_config: false/ntp_manage_config: true/g' ~/kubespray/inventory/mycluster/group_vars/all/all.yml
# Custome file etcd.yml
sed -i 's/# container_manager: containerd/container_manager: docker/g' ~/kubespray/inventory/mycluster/group_vars/all/etcd.yml
sed -i 's/etcd_deployment_type: host/etcd_deployment_type: docker/g' ~/kubespray/inventory/mycluster/group_vars/all/etcd.yml
# Custom file ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
sed -i 's/kube_service_addresses: 10.233.0.0/18/kube_service_addresses: 10.254.0.0/16/g' ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
sed -i 's/kube_pods_subnet: 10.233.64.0/18/kube_pods_subnet: 172.254.0.0/16/g' ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
sed -i 's/cluster_name: cluster.local/cluster_name: '"$domain_name"'/g' ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
#sed -i 's/nodelocaldns_ip: 169.254.25.10/nodelocaldns_ip: 127.0.0.1/g' ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
sed -i 's/container_manager: containerd/container_manager: docker/g' ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
sed -i 's/auto_renew_certificates: false/auto_renew_certificates: true/g' ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
sed -i 's/# auto_renew_certificates_systemd_calendar/auto_renew_certificates_systemd_calendar/g' ~/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
# Custom file addon
sed -i 's/helm_enabled: false/helm_enabled: true/g' /root/kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml
# Install k8s
cd ~/kubespray && ansible-playbook -i ./inventory/mycluster/group_vars/hosts.yml --become --become-user=root --conn-pass-file=/opt/.pass_temp cluster.yml