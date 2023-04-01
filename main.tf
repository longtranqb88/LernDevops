##### Provider
provider "vsphere" {
  user           = var.provider_vsphere_user
  password       = var.provider_vsphere_password
  vsphere_server = var.provider_vsphere_host

  # if you have a self-signed cert
  allow_unverified_ssl = true
}

##### Data sources
data "vsphere_datacenter" "target_dc" {
  name = var.deploy_vsphere_datacenter
}

data "vsphere_datastore" "target_datastore" {
  name          = var.deploy_vsphere_datastore
  datacenter_id = data.vsphere_datacenter.target_dc.id
}

data "vsphere_compute_cluster" "target_cluster" {
  name          = var.deploy_vsphere_cluster
  datacenter_id = data.vsphere_datacenter.target_dc.id
}

data "vsphere_network" "target_network" {
  name          = var.deploy_vsphere_network
  datacenter_id = data.vsphere_datacenter.target_dc.id
}

data "vsphere_virtual_machine" "source_template" {
  name          = var.guest_template
  datacenter_id = data.vsphere_datacenter.target_dc.id
}

##### Resources
# Clones a single Linux VM from a template for Management Ansible Host
resource "vsphere_virtual_machine" "haproxy-nodes" {
  name             = "${var.guest_name_prefix} HA Management"
  resource_pool_id = data.vsphere_compute_cluster.target_cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.target_datastore.id
  folder           = var.deploy_vsphere_folder
  firmware         = var.guest_firmware

  num_cpus = var.guest_vcpu
  memory   = var.guest_memory
  guest_id = data.vsphere_virtual_machine.source_template.guest_id
  scsi_type = data.vsphere_virtual_machine.source_template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.target_network.id
    adapter_type = data.vsphere_virtual_machine.source_template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.source_template.disks[0].size
    eagerly_scrub    = data.vsphere_virtual_machine.source_template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.source_template.disks[0].thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.source_template.id

    customize {
      linux_options {
        host_name = "${var.guest_name_prefix}-ha-manager"
        domain    = var.guest_domain
      }

      network_interface {
        ipv4_address = var.haproxy_ips
        ipv4_netmask = var.guest_ipv4_netmask
      }

      ipv4_gateway    = var.guest_ipv4_gateway
      dns_server_list = var.guest_dns_servers
      dns_suffix_list = var.guest_dns_suffix
    }
  }

  provisioner "file" {
    connection {
      type     = "ssh"
      user     = var.guest_ssh_user
      password = var.guest_ssh_password
      host     = self.guest_ip_addresses[0]
    }
    source = "./.value.txt"
    destination = "/opt/.value.txt"
  }
  
  provisioner "file" {
    connection {
      type     = "ssh"
      user     = var.guest_ssh_user
      password = var.guest_ssh_password
      host     = self.guest_ip_addresses[0]
    }
    source = "./post_install.sh"
    destination = "/opt/post_install.sh"
  }

  provisioner "file" {
    connection {
      type     = "ssh"
      user     = var.guest_ssh_user
      password = var.guest_ssh_password
      host     = self.guest_ip_addresses[0]
    }
    source = "./.pass_temp"
    destination = "/opt/.pass_temp"
  } 

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = var.guest_ssh_user
      password = var.guest_ssh_password
      host     = self.guest_ip_addresses[0]
    }
    on_failure = "continue"
    inline = [
      "echo 'ClientAliveInterval 1200' >> /etc/ssh/sshd_config",
      "echo 'ClientAliveCountMax 3' >> /etc/ssh/sshd_config",
      "systemctl reload sshd"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = var.guest_ssh_user
      password = var.guest_ssh_password
      host     = self.guest_ip_addresses[0]
    }
    on_failure = "continue"
    inline = [
      "chmod 755 /opt/post_install.sh && /opt/post_install.sh"
    ]
  }

  lifecycle {
    ignore_changes = [annotation]
  }
}

resource "vsphere_virtual_machine" "master" {
  count            = length(var.master_ips)
  name             = "${var.guest_name_prefix}-master0${count.index + 1}"
  resource_pool_id = data.vsphere_compute_cluster.target_cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.target_datastore.id
  folder           = var.deploy_vsphere_folder
  firmware         = var.guest_firmware

  num_cpus = var.guest_vcpu
  memory   = var.guest_memory
  guest_id = data.vsphere_virtual_machine.source_template.guest_id
  scsi_type = data.vsphere_virtual_machine.source_template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.target_network.id
    adapter_type = data.vsphere_virtual_machine.source_template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    unit_number      = 0
    size             = data.vsphere_virtual_machine.source_template.disks[0].size
    eagerly_scrub    = data.vsphere_virtual_machine.source_template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.source_template.disks[0].thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.source_template.id

    customize {
      linux_options {
        host_name = "${var.guest_name_prefix}-master0${count.index + 1}"
        domain    = var.guest_domain
      }

      network_interface {
        ipv4_address = lookup(var.master_ips, count.index)
        ipv4_netmask = var.guest_ipv4_netmask
      }

      ipv4_gateway    = var.guest_ipv4_gateway
      dns_server_list = var.guest_dns_servers
      dns_suffix_list = var.guest_dns_suffix
    }
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = var.guest_ssh_user
      password = var.guest_ssh_password
      host     = self.guest_ip_addresses[0]
    }
    on_failure = "continue"
    inline = [
      "echo 'ClientAliveInterval 1200' >> /etc/ssh/sshd_config",
      "echo 'ClientAliveCountMax 3' >> /etc/ssh/sshd_config",
      "systemctl reload sshd",
      "systemctl stop firewalld && systemctl disable firewalld",
      "setenforce 0 && sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux",
      "yum update -y"
    ]
  }

}

resource "vsphere_virtual_machine" "worker" {
  count            = length(var.worker_ips)
  name             = "${var.guest_name_prefix}-worker0${count.index + 1}"
  resource_pool_id = data.vsphere_compute_cluster.target_cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.target_datastore.id
  folder           = var.deploy_vsphere_folder
  firmware         = var.guest_firmware

  num_cpus = var.guest_vcpu
  memory   = var.guest_memory
  guest_id = data.vsphere_virtual_machine.source_template.guest_id
  scsi_type = data.vsphere_virtual_machine.source_template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.target_network.id
    adapter_type = data.vsphere_virtual_machine.source_template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    unit_number      = 0
    size             = data.vsphere_virtual_machine.source_template.disks[0].size
    eagerly_scrub    = data.vsphere_virtual_machine.source_template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.source_template.disks[0].thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.source_template.id

    customize {
      linux_options {
        host_name = "${var.guest_name_prefix}-worker0${count.index + 1}"
        domain    = var.guest_domain
      }

      network_interface {
        ipv4_address = lookup(var.worker_ips, count.index)
        ipv4_netmask = var.guest_ipv4_netmask
      }

      ipv4_gateway    = var.guest_ipv4_gateway
      dns_server_list = var.guest_dns_servers
      dns_suffix_list = var.guest_dns_suffix
    }
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = var.guest_ssh_user
      password = var.guest_ssh_password
      host     = self.guest_ip_addresses[0]
    }
    on_failure = "continue"
    inline = [
      "echo 'ClientAliveInterval 1200' >> /etc/ssh/sshd_config",
      "echo 'ClientAliveCountMax 3' >> /etc/ssh/sshd_config",
      "systemctl reload sshd",
      "systemctl stop firewalld && systemctl disable firewalld",
      "setenforce 0 && sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux",
      "yum update -y"
    ]
  }

}