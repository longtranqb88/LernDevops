# Provider
provider_vsphere_host     = "vcenter.svtech.local"
provider_vsphere_user     = "administrator@svtech.local"
provider_vsphere_password = "P@ssw0rdSVT"

# Infrastructure
deploy_vsphere_datacenter = "SVT_LAB"
deploy_vsphere_cluster    = "Cluster-02"
deploy_vsphere_datastore  = "VT_iSCSI_1TB"
deploy_vsphere_folder     = "/AnNH_System"
deploy_vsphere_network    = "DPortGroup VLAN 1025"

# Guest
guest_name_prefix     = "k8s"
guest_template        = "TL-CentOS-7.9-x64"
guest_vcpu            = "2"
guest_memory          = "2048"
guest_ipv4_netmask    = "24"
guest_ipv4_gateway    = "192.168.25.1"
guest_dns_servers     = ["192.168.21.253","8.8.8.8"]
guest_dns_suffix      = ["svtech.local"]
guest_domain          = "svtech.local"
guest_ssh_user        = "root"
guest_ssh_password    = "Cntt!@#2023"
guest_ssh_key_private = "~/.ssh/id_rsa"
guest_ssh_key_public  = "~/.ssh/id_rsa.pub"
guest_firmware        = "efi"

# Haproxy & Ansible Hosts
haproxy_ips = "192.168.25.221"
# Master(s)
master_ips = {
  "0" = "192.168.25.223"
  "1" = "192.168.25.224"
  "2" = "192.168.25.225"
}

# Worker(s)
worker_ips = {
  "0" = "192.168.25.226"
  "1" = "192.168.25.227"
  "2" = "192.168.25.228"
}
